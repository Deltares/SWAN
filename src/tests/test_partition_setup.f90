!> Exercise SWAN partition administration and MPI halo routines.
program test_partition_setup
   use, intrinsic :: iso_c_binding, only: c_int64_t
   use, intrinsic :: iso_fortran_env, only: output_unit
   use mpi, only: MPI_COMM_WORLD, MPI_INTEGER, MPI_MIN, MPI_REAL, MPI_SUCCESS, MPI_SUM
   use m_parall, only: comm, inode, nproc, master, iammaster, parll, swint, swreal, swsum
   use ocpcomm4, only: ltrace, itest, printf, prtest, leverr, maxerr
   use SwanGriddata, only: nverts, nvertsg, ncells, ncellsg, kvertc, ivertg, vmark, excmark
   use SwanParallel, only: SwanCommAdmin, SwanDecomposition, SwanUvExchgI, SwanUvExchgR, SwanParallelComm, &
                           ipown, vres, vsubcm, nvcomm, nvrecv, nvsend, ivrecv, ivsend, &
                           rrqst, srqst, irbuf, isbuf, rbuf, sbuf
   implicit none

   interface
      function process_bytes() bind(C, name="swan_test_process_bytes") result(bytes)
         import :: c_int64_t
         integer(c_int64_t) :: bytes
      end function process_bytes
   end interface

   integer, parameter :: SWAN_REAL_KIND = kind(0.0)
   integer, parameter :: LARGE_MESH_NX = 64

   integer :: ierr, world_rank, local_rank, world_size, iteration
   integer :: local_memory_available, memory_available
   integer(c_int64_t) :: bytes_before, bytes_after
   integer(c_int64_t), parameter :: growth_limit = 8_c_int64_t * 1024 * 1024
   character(len=24) :: mode

   call MPI_Init(ierr)
   call MPI_Comm_rank(MPI_COMM_WORLD, world_rank, ierr)
   call MPI_Comm_size(MPI_COMM_WORLD, world_size, ierr)
   call get_command_argument(1, mode)
   if (trim(mode) == "metis") then
      call require(world_size == 2 .or. world_size == 4, "The METIS test requires two or four MPI ranks")
   else if (world_size /= 2) then
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
   printf = output_unit
   prtest = output_unit
   leverr = 0
   maxerr = 1
   excmark = 999999
   call require(SwanParallelComm() == comm, "SWAN must use the supplied communicator")

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
   case ("edge_cases")
      call check_partition_edges()
   case ("metis")
      call check_metis_partition()
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
      call fail("Expected connected, disconnected, edge_cases, metis, or repeated test mode")
   end select

   if (iammaster) then
      write (*, '(a,a)') "PASS SWAN partition administration: ", trim(mode)
   end if
   call MPI_Comm_free(comm, ierr)
   call MPI_Finalize(ierr)

contains

   !> Fail the MPI test if an assertion fails.
   subroutine require(condition, message)
      logical, intent(in) :: condition !< Required test condition.
      character(len=*), intent(in) :: message !< Diagnostic on failure.

      if (.not. condition) then
         call fail(message)
      end if
   end subroutine require

   !> Report a test failure and stop all participating processes.
   subroutine fail(message)
      character(len=*), intent(in) :: message !< Diagnostic on failure.
      integer :: abort_error

      write (*, '(a,i0,a,a)') "FAIL rank ", world_rank, ": ", message
      call MPI_Abort(MPI_COMM_WORLD, 1, abort_error)
      error stop 1
   end subroutine fail

   !> Set up a connected mesh shared by two partitions.
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

   !> Set up two isolated triangles with no halo neighbors.
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

   !> Verify connected partition dimensions and halo maps.
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

   !> Verify disconnected partitions and empty halo lists.
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

   !> Verify one ghost vertex and clean rejection of an empty partition.
   subroutine check_partition_edges()
      call prepare_single_triangle()
      ipown = [1, 1, 2]

      call SwanCommAdmin()
      call require(leverr == 0, "Single-triangle partition setup reported an error")
      call require(nvcomm == 1, "Single-triangle partition must have one neighbor")
      call require(nvrecv(1) == inode, "Wrong number of ghosts on single-triangle partition")
      call require(nvsend(1) == 3 - inode, "Wrong number of send vertices on single-triangle partition")
      call check_markers()
      call check_halos()
      call clear_partition()

      call prepare_single_triangle()
      ipown = 1
      ! Record the expected diagnostic without opening rank-specific files.
      maxerr = 4
      call SwanCommAdmin()
      call require(leverr == 4, "A partition without cells must report a terminating error")
      call require(.not. allocated(ivertg), "Empty partition error must precede local mesh creation")
      call require(.not. allocated(rrqst), "Empty partition error must precede halo setup")
      call require(nverts == nvertsg .and. ncells == ncellsg, "Empty partition error changed mesh dimensions")
      deallocate(kvertc, vmark, ipown)
   end subroutine check_partition_edges

   !> Create a triangle whose vertex owners are assigned by the caller.
   subroutine prepare_single_triangle()
      nvertsg = 3
      ncellsg = 1
      nverts = nvertsg
      ncells = ncellsg
      allocate(kvertc(3, ncells), vmark(nverts), ipown(nverts))
      kvertc(:, 1) = [1, 2, 3]
      vmark = [101, 102, 103]
   end subroutine prepare_single_triangle

   !> Verify markers distinguish resident and ghost vertices.
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

   !> Exchange fields and verify the owner values at every vertex.
   subroutine check_halos()
      integer :: vertex
      integer, dimension(:), allocatable :: integer_field
      real(kind=SWAN_REAL_KIND), dimension(:), allocatable :: real_field

      allocate(integer_field(nverts), real_field(nverts))
      integer_field = -1000000
      real_field = -1000000.0_SWAN_REAL_KIND
      do vertex = 1, nverts
         if (vres(vertex)) then
            integer_field(vertex) = 1000 + ivertg(vertex)
            real_field(vertex) = real(ivertg(vertex), kind=SWAN_REAL_KIND) + 0.25_SWAN_REAL_KIND
         end if
      end do
      call SwanUvExchgI(integer_field)
      call SwanUvExchgR(real_field)
      call require(all(integer_field == 1000 + ivertg), "Integer halo values do not match their owners")
      call require(all(real_field == real(ivertg, kind=SWAN_REAL_KIND) + 0.25_SWAN_REAL_KIND), &
                   "Real halo values do not match their owners")
   end subroutine check_halos

   !> Build a mesh large enough to exercise real METIS partitions.
   subroutine prepare_large_mesh()
      integer, parameter :: nx = LARGE_MESH_NX, ny = 9
      integer :: x, y, vertex, cell, lower_left

      nvertsg = nx * ny
      ncellsg = 2 * (nx - 1) * (ny - 1)
      nverts = nvertsg
      ncells = ncellsg
      allocate(kvertc(3, ncells), vmark(nverts))
      do y = 1, ny
         do x = 1, nx
            vertex = x + nx * (y - 1)
            vmark(vertex) = 100 + vertex
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
   end subroutine prepare_large_mesh

   !> Verify the METIS entry point, local ownership, and exchanged values.
   subroutine check_metis_partition()
      logical, dimension(7) :: setup_steps
      integer :: local_count, global_count, status

      call prepare_large_mesh()
      setup_steps = .false.
      call SwanDecomposition(setup_steps)
      call require(setup_steps(7) .and. leverr == 0, "METIS decomposition failed")
      call require(ncells > 0 .and. nvcomm > 0, "Expected a connected partition with cells")
      local_count = count(vres)
      call require(local_count > 0, "Expected resident vertices on every rank")
      call MPI_Allreduce(local_count, global_count, 1, MPI_INTEGER, MPI_SUM, comm, status)
      call require(status == MPI_SUCCESS, "Could not check total vertex ownership")
      call require(global_count == nvertsg, "Expected exactly one owner for every global vertex")
      call check_markers()
      call check_halos()
      call clear_partition()
   end subroutine check_metis_partition

   !> Set up and free the same prescribed partition during the memory check.
   subroutine exercise_large_partition()
      integer :: vertex, x

      call prepare_large_mesh()
      allocate(ipown(nverts))
      do vertex = 1, nverts
         x = mod(vertex - 1, LARGE_MESH_NX) + 1
         ipown(vertex) = merge(1, 2, x <= LARGE_MESH_NX / 2)
      end do
      call SwanCommAdmin()
      call require(leverr == 0, "Repeated partition setup reported an error")
      call require(nvcomm == 1, "Repeated connected partition lost its neighbor")
      call check_markers()
      call check_halos()
      call clear_partition()
   end subroutine exercise_large_partition

   !> Release the mesh and communication data for this test.
   subroutine clear_partition()
      deallocate(kvertc, vmark, ipown, ivertg, vres, vsubcm, nvrecv, nvsend, ivrecv, ivsend)
      deallocate(rrqst, srqst, irbuf, isbuf, rbuf, sbuf)
   end subroutine clear_partition

end program test_partition_setup
