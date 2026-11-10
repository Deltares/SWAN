! Exercise the actual SWAN partition administration and MPI halo routines.
program test_partition_setup
   use, intrinsic :: iso_c_binding, only: c_int64_t
   use mpi
   use m_parall, only: comm, inode, nproc, master, iammaster, parll, swint, swreal, swsum
   use ocpcomm4, only: ltrace, itest, printf, prtest, leverr, maxerr
   use SwanGriddata, only: nverts, nvertsg, ncells, ncellsg, kvertc, ivertg, vmark, excmark
   use SwanParallel, only: SwanCommAdmin, SwanUvExchgI, SwanUvExchgR, SwanParallelComm, &
                           ipown, vres, vsubcm, nvcomm, nvrecv, nvsend, ivrecv, ivsend, &
                           rrqst, srqst, irbuf, isbuf, rbuf, sbuf
   implicit none

   interface
      function process_bytes() bind(C, name="swan_test_process_bytes") result(bytes)
         import :: c_int64_t
         integer(c_int64_t) :: bytes
      end function process_bytes
   end interface

   integer :: ierr, world_rank, local_rank, world_size, iteration
   integer :: local_memory_available, memory_available
   integer(c_int64_t) :: bytes_before, bytes_after
   integer(c_int64_t), parameter :: growth_limit = 8_c_int64_t * 1024 * 1024
   character(len=24) :: mode

   call MPI_Init(ierr)
   call MPI_Comm_rank(MPI_COMM_WORLD, world_rank, ierr)
   call MPI_Comm_size(MPI_COMM_WORLD, world_size, ierr)
   if (world_size /= 2) then
      call fail("This regression test requires exactly two MPI ranks")
   end if
   ! Reverse rank ordering so the test does not depend on MPI_COMM_WORLD.
   call MPI_Comm_split(MPI_COMM_WORLD, 0, world_size - world_rank, comm, ierr)
   call MPI_Comm_rank(comm, local_rank, ierr)
   inode = local_rank + 1
   nproc = world_size
   iammaster = inode == master
   parll = .true.
   swint = MPI_INTEGER
   swreal = MPI_REAL
   swsum = MPI_SUM
   ltrace = .false.
   itest = 0
   printf = 6
   prtest = 6
   leverr = 0
   maxerr = 1
   excmark = 999999
   call require(SwanParallelComm() == comm, "SWAN must use the supplied communicator")

   call get_command_argument(1, mode)
   select case (trim(mode))
   case ("connected")
      call prepare_connected()
      call SwanCommAdmin()
      call check_connected()
      call check_halos()
      call clear_partition()
   case ("disconnected")
      call prepare_disconnected()
      call SwanCommAdmin()
      call check_disconnected()
      call check_halos()
      call clear_partition()
   case ("repeated")
      do iteration = 1, 32
         call exercise_large_partition()
      end do
      bytes_before = process_bytes()
      local_memory_available = 1
      if (bytes_before < 0) then
         local_memory_available = 0
      end if
      call MPI_Allreduce(local_memory_available, memory_available, 1, MPI_INTEGER, MPI_MIN, comm, ierr)
      call require(ierr == MPI_SUCCESS, "Could not agree on process memory measurement availability")
      if (memory_available == 0) then
         if (iammaster) then
            write (*, '(a)') "Process memory measurement is unavailable; skipping growth check"
         end if
         call MPI_Comm_free(comm, ierr)
         call MPI_Finalize(ierr)
         stop 77
      end if
      do iteration = 1, 512
         call exercise_large_partition()
      end do
      bytes_after = process_bytes()
      call require(bytes_after >= 0, "Process memory measurement failed after repeated setup")
      write (*, '(a,i0,a,i0,a)') "Rank ", inode, " process-memory growth: ", bytes_after - bytes_before, " bytes"
      call require(bytes_after - bytes_before <= growth_limit, "Repeated partition setup leaked more than 8 MiB")
   case default
      call fail("Expected connected, disconnected, or repeated test mode")
   end select

   if (iammaster) then
      write (*, '(a,a)') "PASS SWAN partition administration: ", trim(mode)
   end if
   call MPI_Comm_free(comm, ierr)
   call MPI_Finalize(ierr)

contains

   subroutine require(condition, message)
      logical, intent(in) :: condition
      character(len=*), intent(in) :: message

      if (.not. condition) then
         call fail(message)
      end if
   end subroutine require

   subroutine fail(message)
      character(len=*), intent(in) :: message
      integer :: abort_error

      write (*, '(a,i0,a,a)') "FAIL rank ", world_rank, ": ", message
      call MPI_Abort(MPI_COMM_WORLD, 1, abort_error)
      error stop 1
   end subroutine fail

   subroutine prepare_connected()
      integer :: vertex

      nvertsg = 6
      ncellsg = 4
      nverts = nvertsg
      ncells = ncellsg
      allocate(kvertc(3, ncells), vmark(nverts), ipown(nverts))
      kvertc(:, 1) = [1, 2, 5]
      kvertc(:, 2) = [1, 5, 4]
      kvertc(:, 3) = [2, 3, 6]
      kvertc(:, 4) = [2, 6, 5]
      ipown = [1, 1, 2, 1, 1, 2]
      do vertex = 1, nverts
         vmark(vertex) = 100 + vertex
      end do
   end subroutine prepare_connected

   subroutine prepare_disconnected()
      integer :: vertex

      nvertsg = 6
      ncellsg = 2
      nverts = nvertsg
      ncells = ncellsg
      allocate(kvertc(3, ncells), vmark(nverts), ipown(nverts))
      kvertc(:, 1) = [1, 2, 3]
      kvertc(:, 2) = [4, 5, 6]
      ipown = [1, 1, 1, 2, 2, 2]
      do vertex = 1, nverts
         vmark(vertex) = 100 + vertex
      end do
   end subroutine prepare_disconnected

   subroutine check_connected()
      call require(leverr == 0, "Connected partition setup reported an error")
      call require(nvcomm == 1, "Connected partition must have one neighbor")
      call require(all(vsubcm == 3 - inode), "Wrong neighbor rank")
      call require(all(nvrecv == 2) .and. all(nvsend == 2), "Wrong halo sizes")
      if (inode == 1) then
         call require(nverts == 6 .and. ncells == 4, "Wrong rank-1 mesh dimensions")
         call require(all(ivertg == [1, 2, 3, 4, 5, 6]), "Wrong rank-1 local-to-global map")
         call require(all(kvertc(:, 1) == [1, 2, 5]), "Wrong rank-1 cell connectivity")
         call require(all(ivrecv(:, 1) == [3, 6]), "Wrong rank-1 receive map")
         call require(all(ivsend(:, 1) == [2, 5]), "Wrong rank-1 send map")
      else
         call require(nverts == 4 .and. ncells == 2, "Wrong rank-2 mesh dimensions")
         call require(all(ivertg == [2, 3, 5, 6]), "Wrong rank-2 local-to-global map")
         call require(all(kvertc(:, 1) == [1, 2, 4]), "Wrong rank-2 first cell connectivity")
         call require(all(kvertc(:, 2) == [1, 4, 3]), "Wrong rank-2 second cell connectivity")
         call require(all(ivrecv(:, 1) == [1, 3]), "Wrong rank-2 receive map")
         call require(all(ivsend(:, 1) == [2, 4]), "Wrong rank-2 send map")
      end if
      call check_markers()
   end subroutine check_connected

   subroutine check_disconnected()
      call require(leverr == 0, "Disconnected partition setup reported an error")
      call require(nverts == 3 .and. ncells == 1, "Wrong disconnected mesh dimensions")
      call require(all(ivertg == [1, 2, 3] + 3 * (inode - 1)), "Wrong disconnected vertex map")
      call require(all(kvertc(:, 1) == [1, 2, 3]), "Wrong disconnected connectivity")
      call require(all(vres), "Disconnected partition must have no ghost vertices")
      call require(nvcomm == 0, "Disconnected partition must have no neighbor")
      call require(size(nvrecv) == 0 .and. size(nvsend) == 0, "Disconnected halo lists must be empty")
      call require(size(ivrecv) == 0 .and. size(ivsend) == 0, "Disconnected halo maps must be empty")
      call check_markers()
   end subroutine check_disconnected

   subroutine check_markers()
      integer :: vertex

      do vertex = 1, nverts
         call require(vres(vertex) .eqv. (ipown(ivertg(vertex)) == inode), "Wrong resident/ghost flag")
         if (vres(vertex)) then
            call require(vmark(vertex) == 100 + ivertg(vertex), "Resident boundary marker changed")
         else
            call require(vmark(vertex) == excmark, "Ghost boundary marker is missing")
         end if
      end do
   end subroutine check_markers

   subroutine check_halos()
      integer :: vertex
      integer, allocatable :: integer_field(:)
      real, allocatable :: real_field(:)

      allocate(integer_field(nverts), real_field(nverts))
      integer_field = -1000000
      real_field = -1000000.0
      do vertex = 1, nverts
         if (vres(vertex)) then
            integer_field(vertex) = 1000 + ivertg(vertex)
            real_field(vertex) = real(ivertg(vertex)) + 0.25
         end if
      end do
      call SwanUvExchgI(integer_field)
      call SwanUvExchgR(real_field)
      call require(all(integer_field == 1000 + ivertg), "Integer halo values do not match their owners")
      call require(all(real_field == real(ivertg) + 0.25), "Real halo values do not match their owners")
   end subroutine check_halos

   subroutine exercise_large_partition()
      integer, parameter :: nx = 64, ny = 9
      integer :: x, y, vertex, cell, lower_left

      nvertsg = nx * ny
      ncellsg = 2 * (nx - 1) * (ny - 1)
      nverts = nvertsg
      ncells = ncellsg
      allocate(kvertc(3, ncells), vmark(nverts), ipown(nverts))
      do y = 1, ny
         do x = 1, nx
            vertex = x + nx * (y - 1)
            vmark(vertex) = 100 + vertex
            if (x <= nx / 2) then
               ipown(vertex) = 1
            else
               ipown(vertex) = 2
            end if
         end do
      end do
      cell = 0
      do y = 1, ny - 1
         do x = 1, nx - 1
            lower_left = x + nx * (y - 1)
            cell = cell + 1
            kvertc(:, cell) = [lower_left, lower_left + 1, lower_left + nx + 1]
            cell = cell + 1
            kvertc(:, cell) = [lower_left, lower_left + nx + 1, lower_left + nx]
         end do
      end do
      call SwanCommAdmin()
      call require(leverr == 0, "Repeated partition setup reported an error")
      call require(nvcomm == 1, "Repeated connected partition lost its neighbor")
      call check_markers()
      call check_halos()
      call clear_partition()
   end subroutine exercise_large_partition

   subroutine clear_partition()
      deallocate(kvertc, vmark, ipown, ivertg, vres, vsubcm, nvrecv, nvsend, ivrecv, ivsend)
      deallocate(rrqst, srqst, irbuf, isbuf, rbuf, sbuf)
   end subroutine clear_partition

end program test_partition_setup
