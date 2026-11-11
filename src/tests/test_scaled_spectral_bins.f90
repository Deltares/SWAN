!> Verify that scaled NetCDF output preserves valid bins next to fill values.
program test_scaled_spectral_bins
   use, intrinsic :: iso_fortran_env, only: error_unit, int64
   use agioncmd, only: agnc_add_spcdata, agnc_add_spcdata_density, agnc_set_mapgrid, agnc_set_pntgrid, &
                      agnc_set_spcgrid, create_ncfile, mapgrid_type, pntgrid_type, recordaxe_type, spcgrid_type
   use mpi, only: MPI_COMM_SELF, MPI_COMM_WORLD, MPI_SUCCESS
   use m_parall, only: comm
   use netcdf, only: nf90_close, nf90_enddef, nf90_fill_float, nf90_fill_short, nf90_get_att, nf90_get_var, &
                    nf90_inq_varid, nf90_noerr, nf90_nowrite, nf90_open, nf90_put_var, nf90_strerror
   use ocpcomm2, only: projid, projnr, projt1, vertxt
   use ocpcomm3, only: vernum
   use ocpcomm4, only: printf
   use swcomm3, only: degrad
   implicit none

   integer, parameter :: SWAN_REAL_KIND = kind(0.0)
   integer, parameter :: FREQUENCIES = 3, DIRECTIONS = 2, NX = 2, NY = 2, POINTS = NX * NY
   real(SWAN_REAL_KIND), parameter :: MISSING_BIN = nf90_fill_float
   real(SWAN_REAL_KIND), parameter :: PACKED_MAX = 32767.0_SWAN_REAL_KIND
   integer :: rank, mpi_status
   integer(int64) :: run_id

   call MPI_Init(mpi_status)
   if (mpi_status /= MPI_SUCCESS) then
      error stop 'MPI initialization failed.'
   end if
   call MPI_Comm_rank(MPI_COMM_WORLD, rank, mpi_status)
   call require(mpi_status == MPI_SUCCESS, 'MPI rank lookup failed.')
   ! Each rank exercises the writer with its own fixture and file handle.
   comm = MPI_COMM_SELF
   printf = error_unit
   projid = 'bins'
   projnr = '01'
   projt1 = 'Spectral scaling test'
   vertxt = 'Test'
   vernum = 0.0_SWAN_REAL_KIND
   degrad = acos(-1.0_SWAN_REAL_KIND) / 180.0_SWAN_REAL_KIND
   call system_clock(run_id)

   call check_output(.false., .false.)
   call check_output(.true., .false.)
   call check_output(.false., .true.)
   call check_output(.true., .true.)
   call MPI_Finalize(mpi_status)
   if (mpi_status /= MPI_SUCCESS) then
      error stop 'MPI finalization failed.'
   end if

contains

   !> Write and reopen a file using one of SWAN's scaled spectral layouts.
   subroutine check_output(directional, on_map)
      logical, intent(in) :: directional !< Use direction and frequency bins.
      logical, intent(in) :: on_map !< Use a map grid instead of a point list.

      real(SWAN_REAL_KIND), dimension(DIRECTIONS * FREQUENCIES, POINTS) :: expected
      real(SWAN_REAL_KIND), dimension(FREQUENCIES, POINTS) :: energy, theta, spread
      real(SWAN_REAL_KIND), dimension(POINTS) :: peaks
      real(SWAN_REAL_KIND) :: amplitude
      integer :: file_id, unit_id, status, bin_count
      character(len=96) :: path
      character(len=16) :: value_name, scale_name
      type(mapgrid_type) :: map_grid
      type(pntgrid_type) :: point_grid
      type(recordaxe_type) :: record_axis
      type(spcgrid_type) :: spectral_grid

      amplitude = real(rank + 1, SWAN_REAL_KIND)
      expected(:, 1) = [0.125_SWAN_REAL_KIND * amplitude, MISSING_BIN, 0.5_SWAN_REAL_KIND * amplitude, &
                        0.0_SWAN_REAL_KIND, MISSING_BIN, 0.25_SWAN_REAL_KIND * amplitude]
      expected(:, 2) = MISSING_BIN
      expected(:, 3) = 0.75_SWAN_REAL_KIND * amplitude
      expected(:, 4) = 0.0_SWAN_REAL_KIND
      peaks = [0.5_SWAN_REAL_KIND * amplitude, 0.0_SWAN_REAL_KIND, &
               0.75_SWAN_REAL_KIND * amplitude, 0.0_SWAN_REAL_KIND]
      write(path, '("scaled_spectra_",i0,"_",i0,"_",l1,l1,".nc")') run_id, rank, directional, on_map

      record_axis%nstatm = .false.
      spectral_grid%relative = .true.
      spectral_grid%nfreq = FREQUENCIES
      spectral_grid%frequency = [0.1_SWAN_REAL_KIND, 0.2_SWAN_REAL_KIND, 0.3_SWAN_REAL_KIND]
      if (directional) then
         spectral_grid%ndir = DIRECTIONS
         spectral_grid%direction = [0.0_SWAN_REAL_KIND, 90.0_SWAN_REAL_KIND] * degrad
      end if

      if (on_map) then
         map_grid%nx = NX
         map_grid%ny = NY
         map_grid%lunit = 'm'
         map_grid%longitude = reshape([0.0_SWAN_REAL_KIND, 1.0_SWAN_REAL_KIND], [NX, 1])
         map_grid%latitude = reshape([0.0_SWAN_REAL_KIND, 1.0_SWAN_REAL_KIND], [1, NY])
         call create_ncfile(path, file_id, record_axis, mapgrid=map_grid, spcgrid=spectral_grid, Escale=.true.)
         call require_netcdf(nf90_enddef(file_id), 'Completing map definitions')
         call agnc_set_mapgrid(file_id, map_grid)
      else
         point_grid%npoints = POINTS
         point_grid%lunit = 'm'
         point_grid%longitude = [0.0_SWAN_REAL_KIND, 1.0_SWAN_REAL_KIND, 0.0_SWAN_REAL_KIND, 1.0_SWAN_REAL_KIND]
         point_grid%latitude = [0.0_SWAN_REAL_KIND, 0.0_SWAN_REAL_KIND, 1.0_SWAN_REAL_KIND, 1.0_SWAN_REAL_KIND]
         call create_ncfile(path, file_id, record_axis, pntgrid=point_grid, spcgrid=spectral_grid, Escale=.true.)
         call require_netcdf(nf90_enddef(file_id), 'Completing point-list definitions')
         call agnc_set_pntgrid(file_id, point_grid)
      end if
      call agnc_set_spcgrid(file_id, spectral_grid)
      call require_netcdf(nf90_put_var(file_id, record_axis%varid, 1, start=[1]), 'Writing the run number')

      if (directional) then
         call agnc_add_spcdata_density(file_id, 1, expected, on_map)
         value_name = 'density'
         scale_name = 'scale_density'
         bin_count = DIRECTIONS * FREQUENCIES
      else
         energy = expected(:FREQUENCIES, :)
         theta = 0.0_SWAN_REAL_KIND
         spread = 0.0_SWAN_REAL_KIND
         call agnc_add_spcdata(file_id, 1, energy, theta, spread, on_map)
         value_name = 'energy_1d'
         scale_name = 'scale_energy_1d'
         bin_count = FREQUENCIES
      end if
      call require_netcdf(nf90_close(file_id), 'Closing output spectra')
      call require_netcdf(nf90_open(path, nf90_nowrite, file_id), 'Reopening output spectra')
      call check_bins(file_id, value_name, scale_name, expected(:bin_count, :), peaks, directional, on_map)
      call require_netcdf(nf90_close(file_id), 'Closing verified spectra')

      open (newunit=unit_id, file=path, status='old', access='stream', form='unformatted', iostat=status)
      call require(status == 0, 'Opening the test file for cleanup failed.')
      close (unit_id, status='delete', iostat=status)
      call require(status == 0, 'Removing the verified test file failed.')
   end subroutine check_output

   !> Check fill codes, scale factors, and decoded values in the stored data.
   subroutine check_bins(file_id, value_name, scale_name, expected, peaks, directional, on_map)
      integer, intent(in) :: file_id !< Open NetCDF file.
      character(len=*), intent(in) :: value_name !< Packed spectrum variable.
      character(len=*), intent(in) :: scale_name !< Per-point scale variable.
      real(SWAN_REAL_KIND), dimension(:, :), intent(in) :: expected !< Original bins by point.
      real(SWAN_REAL_KIND), dimension(:), intent(in) :: peaks !< Largest valid bin at each point.
      logical, intent(in) :: directional !< Whether the file has a direction axis.
      logical, intent(in) :: on_map !< Whether the file has X and Y axes.

      integer :: value_id, scale_id, fill, packed, point, bin
      integer, dimension(:), allocatable :: point_index, bin_index
      real(SWAN_REAL_KIND) :: scale, expected_scale, decoded

      call require_netcdf(nf90_inq_varid(file_id, value_name, value_id), 'Finding packed spectra')
      call require_netcdf(nf90_inq_varid(file_id, scale_name, scale_id), 'Finding spectral scales')
      call require_netcdf(nf90_get_att(file_id, value_id, '_FillValue', fill), 'Reading the packed fill code')
      call require(fill == nf90_fill_short, 'Packed spectra must retain the NetCDF short fill value.')
      do point = 1, POINTS
         if (on_map) then
            point_index = [mod(point - 1, NX) + 1, (point - 1) / NX + 1, 1]
         else
            point_index = [point, 1]
         end if
         call require_netcdf(nf90_get_var(file_id, scale_id, scale, start=point_index), 'Reading the spectral scale')
         do bin = 1, size(expected, 1)
            if (directional) then
               bin_index = [mod(bin - 1, DIRECTIONS) + 1, (bin - 1) / DIRECTIONS + 1, point_index]
            else
               bin_index = [bin, point_index]
            end if
            call require_netcdf(nf90_get_var(file_id, value_id, packed, start=bin_index), 'Reading a packed bin')
            if (expected(bin, point) == MISSING_BIN) then
               call require(packed == fill, 'Missing bin must be stored as fill.')
            else
               call require(packed >= 0, 'Valid bin must remain a nonnegative packed value.')
               if (expected(bin, point) > 0.0_SWAN_REAL_KIND) then
                  call require(packed > 0, 'Valid positive bin was lost next to a missing bin.')
               end if
               decoded = real(packed, SWAN_REAL_KIND) * scale
               call require(abs(decoded - expected(bin, point)) <= 0.501_SWAN_REAL_KIND * scale, &
                            'Decoded bin differs by more than half a quantization step.')
            end if
         end do
         expected_scale = max(peaks(point) / PACKED_MAX, epsilon(1.0_SWAN_REAL_KIND))
         call require(abs(scale / expected_scale - 1.0_SWAN_REAL_KIND) <= 1.0e-6_SWAN_REAL_KIND, &
                      'Scale must use valid bins and retain its minimum for empty or zero spectra.')
      end do
   end subroutine check_bins

   !> Report a failed NetCDF operation with the library diagnostic.
   subroutine require_netcdf(status, operation)
      integer, intent(in) :: status !< NetCDF return code.
      character(len=*), intent(in) :: operation !< Operation being checked.

      call require(status == nf90_noerr, operation // ': ' // trim(nf90_strerror(status)))
   end subroutine require_netcdf

   !> Fail the MPI test if a rank observes an incorrect result.
   subroutine require(condition, message)
      logical, intent(in) :: condition !< Expected condition.
      character(len=*), intent(in) :: message !< Diagnostic on failure.

      integer :: abort_status

      if (.not. condition) then
         write (error_unit, '(a,i0,2a)') 'Rank ', rank, ': ', message
         call MPI_Abort(MPI_COMM_WORLD, 1, abort_status)
      end if
   end subroutine require
end program test_scaled_spectral_bins
