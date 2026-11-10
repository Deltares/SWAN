!> Check that the assembled spectral file contains two distinct hourly records.
program check_spectral_records
   use, intrinsic :: iso_fortran_env, only: error_unit, int64, real32
   use netcdf, only: nf90_close, nf90_fill_float, nf90_get_var, nf90_inq_dimid, nf90_inq_varid, &
                    nf90_inquire_dimension, nf90_inquire_variable, nf90_max_var_dims, &
                    nf90_noerr, nf90_nowrite, nf90_open, nf90_strerror
   implicit none

   integer(int64), parameter :: SECONDS_PER_HOUR = 3600_int64
   integer, parameter :: EXPECTED_RECORDS = 2
   character(len=:), allocatable :: path
   integer :: path_length, file_id, time_id, time_dim, density_id, status, records, dimensions, i
   integer, dimension(nf90_max_var_dims) :: dimension_ids
   integer, dimension(5) :: first, counts
   integer(int64), dimension(EXPECTED_RECORDS) :: times
   real(real32), dimension(:, :, :, :), allocatable :: point_density
   real(real32), dimension(:, :, :, :, :), allocatable :: map_density

   call get_command_argument(1, length=path_length, status=status)
   if (status /= 0 .or. path_length == 0) then
      error stop 'Pass the path of the collected NetCDF spectra.'
   end if
   allocate(character(len=path_length) :: path)
   call get_command_argument(1, value=path, status=status)
   if (status /= 0) then
      error stop 'Cannot read the NetCDF spectra path.'
   end if

   file_id = -1
   read_spectra: block
      status = nf90_open(path, nf90_nowrite, file_id)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      status = nf90_inq_dimid(file_id, 'time', time_dim)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      status = nf90_inquire_dimension(file_id, time_dim, len=records)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      if (records /= EXPECTED_RECORDS) then
         exit read_spectra
      end if
      status = nf90_inq_varid(file_id, 'time', time_id)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      status = nf90_get_var(file_id, time_id, times)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      status = nf90_inq_varid(file_id, 'density', density_id)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      status = nf90_inquire_variable(file_id, density_id, ndims=dimensions, dimids=dimension_ids)
      if (status /= nf90_noerr) then
         exit read_spectra
      end if
      if (dimensions < 4 .or. dimensions > size(counts)) then
         exit read_spectra
      end if
      if (dimension_ids(dimensions) /= time_dim) then
         exit read_spectra
      end if
      do i = 1, dimensions
         status = nf90_inquire_dimension(file_id, dimension_ids(i), len=counts(i))
         if (status /= nf90_noerr) then
            exit read_spectra
         end if
      end do
      first = 1
      if (dimensions == 4) then
         allocate(point_density(counts(1), counts(2), counts(3), counts(4)))
         status = nf90_get_var(file_id, density_id, point_density, start=first(:4), count=counts(:4))
      else
         allocate(map_density(counts(1), counts(2), counts(3), counts(4), counts(5)))
         status = nf90_get_var(file_id, density_id, map_density, start=first, count=counts)
      end if
   end block read_spectra
   if (file_id /= -1) then
      i = nf90_close(file_id)
      if (status == nf90_noerr) then
         status = i
      end if
   end if
   if (status /= nf90_noerr) then
      write(error_unit, '(a)') trim(nf90_strerror(status))
      error stop 1
   end if
   if (.not. allocated(point_density) .and. .not. allocated(map_density)) then
      error stop 'Expected spectra with two time records.'
   end if
   if (times(2) - times(1) /= SECONDS_PER_HOUR) then
      error stop 'Spectral output times should be one hour apart.'
   end if
   do i = 1, EXPECTED_RECORDS
      if (allocated(point_density)) then
         if (.not. any(valid_density(point_density(:, :, :, i)))) then
            error stop 'Expected nonzero point spectra in both records.'
         end if
      else
         if (.not. any(valid_density(map_density(:, :, :, :, i)))) then
            error stop 'Expected nonzero map spectra in both records.'
         end if
      end if
   end do

contains

   !> Identify positive spectral values that are distinct from the fill value.
   elemental function valid_density(density) result(valid)
      real(real32), intent(in) :: density !< Stored spectral density or packed bin.
      logical :: valid !< Whether this bin has a positive spectral value.

      valid = density > 0.0_real32 .and. density < real(nf90_fill_float, real32)
   end function valid_density
end program check_spectral_records
