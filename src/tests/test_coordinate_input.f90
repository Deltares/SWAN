!> Exercise coordinate input and localization through production code.
program test_coordinate_input
   use, intrinsic :: iso_fortran_env, only: iostat_end
   use m_swan_coordinate_input, only: read_coordinate_array, shift_coordinates
   use hrextensions, only: swn_hre_readcoordarray
   use netcdf, only: &
      nf90_clobber, nf90_close, nf90_create, nf90_def_dim, &
      nf90_def_var, nf90_double, nf90_enddef, nf90_int, &
      nf90_noerr, nf90_nowrite, nf90_open, nf90_put_att, &
      nf90_put_var, nf90_strerror
   use ocpcomm4, only: ltrace, itest, printf, prtest, leverr, maxerr, iunmin, iunmax
   use swcomm2, only: RK => SWAN_REAL_KIND, DP => SWAN_COORD_KIND, numgrd, xoffs, yoffs, lxoffs, lcoordshift, excfld
   use m_parall, only: parll, iammaster, inode
   implicit none

   ! SWAN's INAR2D/FOR and diagnostic globals use positive legacy units.
   ! Keep their named handles here; standalone deletion uses NEWUNIT below.
   integer, parameter :: SERIES_UNIT = 33
   integer, parameter :: NX = 3
   integer, parameter :: NY = 2
   integer, parameter :: DATA_UNIT = 31
   integer, parameter :: LOG_UNIT = 32
   real(kind=DP), parameter, dimension(NX,NY) :: X_VALUES = reshape([ &
      100000000.125_DP, 100000020.375_DP, 100000040.625_DP, &
      100000001.250_DP, 100000021.500_DP, 100000041.750_DP], [NX,NY])
   real(kind=DP), parameter, dimension(NX,NY) :: Y_VALUES = reshape([ &
      500000000.875_DP, 500000002.125_DP, 500000003.375_DP, &
      500000031.500_DP, 500000032.750_DP, 500000034.000_DP], [NX,NY])
   real(kind=RK), parameter, dimension(NX,NY) :: EXPECTED_X = reshape([ &
      0.0_RK, 20.25_RK, 40.5_RK, 1.125_RK, 21.375_RK, 41.625_RK], [NX,NY])
   real(kind=RK), parameter, dimension(NX,NY) :: EXPECTED_Y = reshape([ &
      0.0_RK, 1.25_RK, 2.5_RK, 30.625_RK, 31.875_RK, 33.125_RK], [NX,NY])
   integer :: test_layout
   integer :: test_format
   integer :: test_cycle
   integer :: failure_count
   integer :: program_io_status

   failure_count = 0
   open(unit=LOG_UNIT, status='scratch', form='formatted', iostat=program_io_status)
   call check_io(program_io_status, 'open in main')
   if (program_io_status /= 0) then
      error stop 1
   end if
   ltrace = .false.
   itest = 0
   printf = LOG_UNIT
   prtest = LOG_UNIT
   leverr = 0
   maxerr = 3
   parll = .false.
   iammaster = .true.
   inode = 1

   do test_format = 0, 1
      do test_layout = 1, 6
         call check_formatted(test_layout, test_format)
      end do
   end do
   do test_layout = 1, 6
      call check_unformatted(test_layout)
   end do
   call check_unformatted_scaling()
   call check_invalid_unit(0, 0)
   call check_invalid_unit(-1, -1)
   call check_invalid_unit(0, DATA_UNIT)
   call check_invalid_unit(-1, DATA_UNIT)
   call check_series()
   call check_netcdf()
   call check_netcdf_missing_and_packed()
   call check_translated_coordinates()
   call check_missing_leading_point(0.0_RK, 0.0_RK)
   call check_missing_leading_point(-999.0_RK, -888.0_RK)
   call check_mismatched_missing(.true.)
   call check_mismatched_missing(.false.)
   call check_no_valid_points()
   call check_existing_origin()
   do test_cycle = 1, 2
      call check_initialization_cycle(test_cycle)
   end do

   if (failure_count /= 0) then
      rewind(LOG_UNIT, iostat=program_io_status)
      call check_io(program_io_status, 'rewind diagnostic log')
      call print_diagnostics()
   end if
   call close_owned_unit(DATA_UNIT)
   call close_owned_unit(SERIES_UNIT)
   close(LOG_UNIT, iostat=program_io_status)
   call check_io(program_io_status, 'close in main')
   if (failure_count /= 0) then
      error stop 1
   end if
   write(*, '(a)', iostat=program_io_status) 'PASS SWAN coordinate input and localization'
   call check_io(program_io_status, 'write in main')
   if (program_io_status /= 0) then
      error stop 1
   end if
contains

   !> Record a failed assertion without terminating a helper.
   subroutine require(condition, message)
      logical, intent(in) :: condition  !< Whether the assertion passed.
      character(len=*), intent(in) :: message  !< Failure description.

      integer :: io_status

      if (.not. condition) then
         failure_count = failure_count + 1
         write(*, '(a,a)', iostat=io_status) 'FAIL: ', message
         if (io_status /= 0) then
            failure_count = failure_count + 1
         end if
      end if
   end subroutine require

   !> Check a Fortran file operation and record its failure.
   subroutine check_io(status, operation)
      integer, intent(in) :: status  !< Returned I/O status.
      character(len=*), intent(in) :: operation  !< Operation description for
      !! diagnostics.

      call require(status == 0, 'Fortran I/O failed: '//operation)
   end subroutine check_io

   !> Close an owned Fortran unit that remains connected after a test.
   subroutine close_owned_unit(unit_number)
      integer, intent(in) :: unit_number  !< Owned legacy file handle.

      integer :: io_status
      logical :: connected

      inquire(unit=unit_number, opened=connected, iostat=io_status)
      call check_io(io_status, 'inquire during final cleanup')
      if (io_status /= 0) then
         return
      end if
      if (connected) then
         close(unit_number, iostat=io_status)
         call check_io(io_status, 'close during final cleanup')
      end if
   end subroutine close_owned_unit

   !> Write the captured SWAN diagnostic log.
   subroutine print_diagnostics()
      character(len=256) :: line
      integer :: read_status
      integer :: io_status

      do
         read(LOG_UNIT, '(a)', iostat=read_status) line
         if (read_status /= 0) then
            if (read_status /= iostat_end) then
               call check_io(read_status, 'read diagnostic log')
            end if
            exit
         end if
         write(*, '(a)', iostat=io_status) trim(line)
         call check_io(io_status, 'write in print_diagnostics')
      end do
   end subroutine print_diagnostics

   !> Reset coordinate state before each regression case.
   subroutine reset_coordinates()
      leverr = 0
      xoffs = 0.0_DP
      yoffs = 0.0_DP
      lxoffs = .false.
      lcoordshift = .false.
      excfld(8:9) = 0.0_RK
   end subroutine reset_coordinates

   !> Write one test record using the requested file format.
   subroutine write_vector(values, format_kind)
      real(kind=DP), intent(in), dimension(:) :: values  !<
      !! Coordinate values for the current record or field.
      integer, intent(in) :: format_kind  !< Legacy format code; negative
      !! selects binary input.

      integer :: io_status

      if (format_kind < 0) then
         write(DATA_UNIT, iostat=io_status) real(values, kind=RK)
         call check_io(io_status, 'write in write_vector')
      else if (format_kind == 0) then
         write(DATA_UNIT, *, iostat=io_status) values
         call check_io(io_status, 'write in write_vector')
      else
         write(DATA_UNIT, '(6f24.8)', iostat=io_status) values
         call check_io(io_status, 'write in write_vector')
      end if
   end subroutine write_vector

   !> Write a coordinate field in one of the six legacy layouts.
   subroutine write_field(values, layout, format_kind)
      real(kind=DP), intent(in), dimension(NX,NY) :: values  !<
      !! Coordinate values for the current record or field.
      integer, intent(in) :: layout  !< Coordinate storage layout from one
      !! through six.
      integer, intent(in) :: format_kind  !< Legacy format code; negative
      !! selects binary input.

      integer :: row
      integer :: column
      integer :: io_status

      if (format_kind < 0) then
         write(DATA_UNIT, iostat=io_status) 'coordinate field'
         call check_io(io_status, 'write in write_field')
      else
         write(DATA_UNIT, '(a)', iostat=io_status) 'coordinate field'
         call check_io(io_status, 'write in write_field')
      end if
      select case (layout)
      case (1)
         do row = NY, 1, -1
            call write_vector(values(:,row), format_kind)
         end do
      case (2)
         call write_vector([values(:,2), values(:,1)], format_kind)
      case (3)
         do row = 1, NY
            call write_vector(values(:,row), format_kind)
         end do
      case (4)
         call write_vector(reshape(values, [NX*NY]), format_kind)
      case (5)
         do column = 1, NX
            call write_vector(values(column,:), format_kind)
         end do
      case (6)
         call write_vector([values(1,:), values(2,:), values(3,:)], format_kind)
      case default
         call require(.false., 'Unsupported coordinate test layout')
      end select
   end subroutine write_field

   !> Read both coordinate components through the production reader.
   subroutine read_pair(layout, format_kind, factor, xread, yread)
      integer, intent(in) :: layout  !< Coordinate storage layout from one
      !! through six.
      integer, intent(in) :: format_kind  !< Legacy format code; negative
      !! selects binary input.
      real(kind=RK), intent(in) :: factor  !< Scale factor applied before
      !! localization.
      real(kind=DP), intent(out), dimension(NX,NY) :: xread  !< Read X
      !! coordinate values.
      real(kind=DP), intent(out), dimension(NX,NY) :: yread  !< Read Y
      !! coordinate values.

      integer :: data_source
      integer :: file_list
      integer :: read_layout

      data_source = DATA_UNIT
      file_list = 0
      read_layout = layout
      xread = 0.0_DP
      yread = 0.0_DP
      call read_coordinate_array(xread, NX, NY, file_list, data_source, &
                             format_kind, '(6f24.8)', read_layout, factor, 1, 0)
      call require(leverr == 0, 'Reading X coordinates reported an error')
      call read_coordinate_array(yread, NX, NY, file_list, data_source, &
                             format_kind, '(6f24.8)', read_layout, factor, 1, 0)
      call require(leverr == 0, 'Reading Y coordinates reported an error')
      call require(read_layout == layout, 'Reader changed a successful layout code')
   end subroutine read_pair

   !> Check formatted layouts, headers, scaling, and localization.
   subroutine check_formatted(layout, format_kind)
      integer, intent(in) :: layout  !< Coordinate storage layout from one
      !! through six.
      integer, intent(in) :: format_kind  !< Legacy format code; negative
      !! selects binary input.

      real(kind=RK) :: factor
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      integer :: io_status

      call reset_coordinates()
      factor = real(format_kind + 1, kind=RK)
      open(unit=DATA_UNIT, status='scratch', form='formatted', iostat=io_status)
      call check_io(io_status, 'open in check_formatted')
      if (io_status /= 0) then
         return
      end if
      call write_field(X_VALUES, layout, format_kind)
      call write_field(Y_VALUES, layout, format_kind)
      rewind(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'rewind in check_formatted')
      call read_pair(layout, format_kind, factor, xread, yread)
      close(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'close in check_formatted')
      call require(all(xread == X_VALUES*real(factor, kind=DP)), 'Formatted X input lost precision or ordering')
      call require(all(yread == Y_VALUES*real(factor, kind=DP)), 'Formatted Y input lost precision or ordering')
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Formatted coordinate localization reported an error')
      call require(lxoffs .and. lcoordshift, 'Coordinate initialization flags were not set')
      call require(xoffs == X_VALUES(1,1)*real(factor, kind=DP), 'X origin lost coordinate precision')
      call require(yoffs == Y_VALUES(1,1)*real(factor, kind=DP), 'Y origin lost coordinate precision')
      call require(all(xlocal == EXPECTED_X*factor), 'Localized X coordinates lost small distances')
      call require(all(ylocal == EXPECTED_Y*factor), 'Localized Y coordinates lost small distances')
   end subroutine check_formatted

   !> Check compatibility with legacy real binary records.
   subroutine check_unformatted(layout)
      integer, intent(in) :: layout  !< Coordinate storage layout from one
      !! through six.

      real(kind=DP), dimension(NX,NY) :: xbinary
      real(kind=DP), dimension(NX,NY) :: ybinary
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      integer :: io_status

      call reset_coordinates()
      xbinary = real(EXPECTED_X, kind=DP) + 10.125_DP
      ybinary = real(EXPECTED_Y, kind=DP) + 20.875_DP
      open(unit=DATA_UNIT, status='scratch', form='unformatted', iostat=io_status)
      call check_io(io_status, 'open in check_unformatted')
      if (io_status /= 0) then
         return
      end if
      call write_field(xbinary, layout, -1)
      call write_field(ybinary, layout, -1)
      rewind(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'rewind in check_unformatted')
      call read_pair(layout, -1, 0.5_RK, xread, yread)
      close(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'close in check_unformatted')
      call require(all(xread == xbinary*0.5_DP), 'Legacy REAL binary X input changed')
      call require(all(yread == ybinary*0.5_DP), 'Legacy REAL binary Y input changed')
   end subroutine check_unformatted

   !> Check that binary scaling precedes no precision loss.
   subroutine check_unformatted_scaling()
      real(kind=DP), dimension(NX,NY) :: xbinary
      real(kind=DP), dimension(NX,NY) :: ybinary
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal
      integer :: io_status

      call reset_coordinates()
      xbinary = real(EXPECTED_X, kind=DP) + 1.0_DP
      ybinary = real(EXPECTED_Y, kind=DP) + 2.0_DP
      ! Both neighbors are exactly representable in the legacy REAL file.
      xbinary(2,1) = 1.0_DP + 2.0_DP**(-23)
      open(unit=DATA_UNIT, status='scratch', form='unformatted', iostat=io_status)
      call check_io(io_status, 'open in check_unformatted_scaling')
      if (io_status /= 0) then
         return
      end if
      call write_field(xbinary, 4, -1)
      call write_field(ybinary, 4, -1)
      rewind(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'rewind in check_unformatted_scaling')
      call read_pair(4, -1, 1.0e8_RK, xread, yread)
      close(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'close in check_unformatted_scaling')
      call require(all(xread == xbinary*1.0e8_DP), 'Binary X scaling rounded before localization')
      call require(all(yread == ybinary*1.0e8_DP), 'Binary Y scaling rounded before localization')
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Scaled binary coordinate localization reported an error')
      call require(xlocal(2,1) == real(11.920928955078125_DP, kind=RK), 'Binary scaling lost a represented neighbor separation')
   end subroutine check_unformatted_scaling

   !> Check the legacy reader invalid-unit contract.
   subroutine check_invalid_unit(format_kind, bad_unit)
      integer, intent(in) :: format_kind  !< Legacy format code; negative
      !! selects binary input.
      integer, intent(in) :: bad_unit  !< Invalid handle under the legacy
      !! positive-unit contract.

      integer :: data_source
      integer :: read_layout
      real(kind=DP), dimension(NX,NY) :: values

      call reset_coordinates()
      data_source = bad_unit
      read_layout = 4
      values = 123.0_DP
      call read_coordinate_array(values, NX, NY, 0, data_source, format_kind, &
                             '(6f24.8)', read_layout, 1.0_RK, 0, 0)
      call require(leverr >= 2, 'Invalid coordinate input unit was accepted')
      call require(read_layout == -2, 'Invalid input unit did not return a failed layout code')
   end subroutine check_invalid_unit

   !> Check file-series rollover and separate header counts.
   subroutine check_series()
      character(len=*), parameter :: FIRST_FILE = 'swan_coordinate_series_first.dat'
      character(len=*), parameter :: SECOND_FILE = 'swan_coordinate_series_second.dat'
      integer :: data_source
      integer :: read_layout
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal
      integer :: io_status

      call reset_coordinates()
      iunmin = 0
      iunmax = 99999
      open(unit=DATA_UNIT, file=FIRST_FILE, status='replace', form='formatted', iostat=io_status)
      call check_io(io_status, 'open in check_series')
      if (io_status /= 0) then
         return
      end if
      call write_field(X_VALUES, 4, 0)
      close(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'close in check_series')
      open(unit=DATA_UNIT, file=SECOND_FILE, status='replace', form='formatted', iostat=io_status)
      call check_io(io_status, 'open in check_series')
      if (io_status /= 0) then
         return
      end if
      write(DATA_UNIT, '(a)', iostat=io_status) 'new coordinate file header'
      call check_io(io_status, 'write in check_series')
      call write_field(Y_VALUES, 4, 0)
      close(DATA_UNIT, iostat=io_status)
      call check_io(io_status, 'close in check_series')
      open(unit=SERIES_UNIT, status='scratch', form='formatted', iostat=io_status)
      call check_io(io_status, 'open in check_series')
      if (io_status /= 0) then
         return
      end if
      write(SERIES_UNIT, '(a)', iostat=io_status) SECOND_FILE
      call check_io(io_status, 'write in check_series')
      rewind(SERIES_UNIT, iostat=io_status)
      call check_io(io_status, 'rewind in check_series')
      open(unit=DATA_UNIT, file=FIRST_FILE, status='old', form='formatted', iostat=io_status)
      call check_io(io_status, 'open in check_series')
      if (io_status /= 0) then
         return
      end if
      data_source = DATA_UNIT
      read_layout = 4
      call read_coordinate_array(xread, NX, NY, SERIES_UNIT, data_source, 0, '(6f24.8)', read_layout, 1.0_RK, 1, 1)
      call require(leverr == 0, 'Reading first coordinate SERIES file reported an error')
      call read_coordinate_array(yread, NX, NY, SERIES_UNIT, data_source, 0, '(6f24.8)', read_layout, 1.0_RK, 1, 1)
      call require(leverr == 0, 'Coordinate SERIES rollover reported an error')
      close(data_source, status='delete', iostat=io_status)
      call check_io(io_status, 'close in check_series')
      close(SERIES_UNIT, iostat=io_status)
      call check_io(io_status, 'close in check_series')
      open(unit=DATA_UNIT, file=FIRST_FILE, status='old', form='formatted', iostat=io_status)
      call check_io(io_status, 'open in check_series')
      if (io_status /= 0) then
         return
      end if
      close(DATA_UNIT, status='delete', iostat=io_status)
      call check_io(io_status, 'close in check_series')
      call require(all(xread == X_VALUES), 'First coordinate SERIES field changed')
      call require(all(yread == Y_VALUES), 'SERIES headers or rollover changed the second field')
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Coordinate SERIES localization reported an error')
      call require(all(xlocal == EXPECTED_X), 'Coordinate SERIES changed X distances')
      call require(all(ylocal == EXPECTED_Y), 'Coordinate SERIES changed Y distances')
   end subroutine check_series

   !> Check double-precision NetCDF coordinates and scaling.
   subroutine check_netcdf()
      character(len=*), parameter :: FILENAME = 'swan_coordinate_input_test.nc'
      integer :: cleanup_unit
      integer :: ncid
      integer :: xdimension
      integer :: ydimension
      integer :: xvariable
      integer :: yvariable
      integer, dimension(numgrd) :: data_files
      integer, dimension(numgrd) :: xsize
      integer, dimension(numgrd) :: ysize
      real(kind=RK), dimension(numgrd) :: factors
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal
      real(kind=DP), dimension(numgrd) :: times
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      integer :: io_status

      call reset_coordinates()
      call check_nc(nf90_create(FILENAME, nf90_clobber, ncid), 'create coordinate NetCDF file')
      call check_nc(nf90_def_dim(ncid, 'x', NX, xdimension), 'define X dimension')
      call check_nc(nf90_def_dim(ncid, 'y', NY, ydimension), 'define Y dimension')
      ! IGR 8/9 use these names in the existing SWAN NetCDF field table.
      call check_nc(nf90_def_var(ncid, 'latitude', nf90_double, [xdimension,ydimension], xvariable), &
                    'define first coordinate variable')
      call check_nc(nf90_def_var(ncid, 'longitude', nf90_double, [xdimension,ydimension], yvariable), &
                    'define second coordinate variable')
      call check_nc(nf90_put_att(ncid, xvariable, '_FillValue', 0.0_DP), 'define first coordinate missing value')
      call check_nc(nf90_put_att(ncid, yvariable, '_FillValue', 0.0_DP), 'define second coordinate missing value')
      call check_nc(nf90_enddef(ncid), 'finish coordinate variable definitions')
      call check_nc(nf90_put_var(ncid, xvariable, X_VALUES), 'write first coordinate variable')
      call check_nc(nf90_put_var(ncid, yvariable, Y_VALUES), 'write second coordinate variable')
      call check_nc(nf90_close(ncid), 'close written coordinate file')
      call check_nc(nf90_open(FILENAME, nf90_nowrite, ncid), 'open coordinate input file')
      data_files = 0
      data_files(8:9) = -ncid
      xsize = NX
      ysize = NY
      times = 0.0_DP
      factors = 2.0_RK
      xread = 0.0_DP
      yread = 0.0_DP
      call swn_hre_readcoordarray(data_files, xread, xsize, ysize, times, factors, 8, FILENAME)
      call require(leverr == 0, 'Reading first NetCDF coordinate variable reported an error')
      call swn_hre_readcoordarray(data_files, yread, xsize, ysize, times, factors, 9, FILENAME)
      call require(leverr == 0, 'Reading second NetCDF coordinate variable reported an error')
      call check_nc(nf90_close(ncid), 'close coordinate input file')
      open(newunit=cleanup_unit, file=FILENAME, status='old', access='stream', form='unformatted', iostat=io_status)
      call check_io(io_status, 'open in check_netcdf')
      if (io_status /= 0) then
         return
      end if
      close(cleanup_unit, status='delete', iostat=io_status)
      call check_io(io_status, 'close in check_netcdf')
      call require(all(xread == 2.0_DP*X_VALUES), 'NetCDF X coordinates lost coordinate precision')
      call require(all(yread == 2.0_DP*Y_VALUES), 'NetCDF Y coordinates lost coordinate precision')
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'NetCDF coordinate localization reported an error')
      call require(all(xlocal == 2.0_RK*EXPECTED_X), 'NetCDF localization lost X distances')
      call require(all(ylocal == 2.0_RK*EXPECTED_Y), 'NetCDF localization lost Y distances')
   end subroutine check_netcdf

   !> Check packed NetCDF attributes and missing-coordinate handling.
   subroutine check_netcdf_missing_and_packed()
      character(len=*), parameter :: FILENAME = 'swan_coordinate_packed_test.nc'
      real(kind=DP), parameter :: MISSING_Y = -9999.123456789_DP
      real(kind=DP), parameter :: PACKED_SCALE = 0.00100000006103515625_DP
      real(kind=DP), parameter :: PACKED_OFFSET = 100000000.125_DP
      integer, parameter :: MISSING_X = -32768
      integer :: cleanup_unit
      integer :: ncid
      integer :: xdimension
      integer :: ydimension
      integer :: xvariable
      integer :: yvariable
      integer, dimension(numgrd) :: data_files
      integer, dimension(numgrd) :: xsize
      integer, dimension(numgrd) :: ysize
      integer, dimension(NX,NY) :: packed_x
      real(kind=RK), dimension(numgrd) :: factors
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal
      real(kind=DP), dimension(numgrd) :: times
      real(kind=DP), dimension(NX,NY) :: ydata
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=DP), dimension(NX,NY) :: wanted_x
      real(kind=DP), dimension(NX,NY) :: wanted_y
      integer :: io_status

      call reset_coordinates()
      excfld(8) = -999.0_RK
      excfld(9) = -888.0_RK
      packed_x = nint(EXPECTED_X*1024.0_RK)
      packed_x(2,1) = MISSING_X
      ydata = Y_VALUES
      ydata(2,1) = MISSING_Y
      call check_nc(nf90_create(FILENAME, nf90_clobber, ncid), 'create packed coordinate NetCDF file')
      call check_nc(nf90_def_dim(ncid, 'x', NX, xdimension), 'define packed X dimension')
      call check_nc(nf90_def_dim(ncid, 'y', NY, ydimension), 'define packed Y dimension')
      call check_nc(nf90_def_var(ncid, 'latitude', nf90_int, [xdimension,ydimension], xvariable), &
                    'define packed coordinate variable')
      call check_nc(nf90_def_var(ncid, 'longitude', nf90_double, [xdimension,ydimension], yvariable), &
                    'define double coordinate variable with missing values')
      call check_nc(nf90_put_att(ncid, xvariable, '_FillValue', MISSING_X), 'define packed missing value')
      call check_nc(nf90_put_att(ncid, xvariable, 'scale_factor', PACKED_SCALE), 'define double scale factor')
      call check_nc(nf90_put_att(ncid, xvariable, 'add_offset', PACKED_OFFSET), 'define double coordinate offset')
      call check_nc(nf90_put_att(ncid, yvariable, '_FillValue', MISSING_Y), 'define double missing value')
      call check_nc(nf90_enddef(ncid), 'finish packed coordinate definitions')
      call check_nc(nf90_put_var(ncid, xvariable, packed_x), 'write packed coordinates')
      call check_nc(nf90_put_var(ncid, yvariable, ydata), 'write double coordinates with a missing value')
      call check_nc(nf90_close(ncid), 'close written packed coordinate file')
      call check_nc(nf90_open(FILENAME, nf90_nowrite, ncid), 'open packed coordinate input')
      data_files = 0
      data_files(8:9) = -ncid
      xsize = NX
      ysize = NY
      times = 0.0_DP
      factors = 2.0_RK
      call swn_hre_readcoordarray(data_files, xread, xsize, ysize, times, factors, 8, FILENAME)
      call require(leverr == 0, 'Reading packed coordinate input reported an error')
      call swn_hre_readcoordarray(data_files, yread, xsize, ysize, times, factors, 9, FILENAME)
      call require(leverr == 0, 'Reading double missing coordinates reported an error')
      call check_nc(nf90_close(ncid), 'close packed coordinate input')
      open(newunit=cleanup_unit, file=FILENAME, status='old', access='stream', form='unformatted', iostat=io_status)
      call check_io(io_status, 'open in check_netcdf_missing_and_packed')
      if (io_status /= 0) then
         return
      end if
      close(cleanup_unit, status='delete', iostat=io_status)
      call check_io(io_status, 'close in check_netcdf_missing_and_packed')
      wanted_x = 2.0_DP*(real(packed_x, kind=DP)*PACKED_SCALE+PACKED_OFFSET)
      wanted_y = 2.0_DP*Y_VALUES
      wanted_x(2,1) = real(excfld(8), kind=DP)
      wanted_y(2,1) = real(excfld(9), kind=DP)
      call require(all(abs(xread-wanted_x) < 3.0e-8_DP), 'Packed metadata lost precision or scaled its missing value')
      call require(all(yread == wanted_y), 'Double missing value was not mapped to the coordinate sentinel')
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Packed/missing NetCDF coordinate localization reported an error')
      call require(xlocal(2,1) == excfld(8), 'Packed missing X coordinate lost its sentinel')
      call require(ylocal(2,1) == excfld(9), 'Double missing Y coordinate lost its sentinel')
      call require(xlocal(3,2) == real(85.248005203125_DP, kind=RK), 'Packed metadata changed local X distances')
      call require(ylocal(3,2) == 2.0_RK*EXPECTED_Y(3,2), 'Double missing metadata changed local Y distances')
   end subroutine check_netcdf_missing_and_packed

   !> Check a NetCDF library result and report its context.
   subroutine check_nc(status, operation)
      integer, intent(in) :: status  !< Returned I/O status.
      character(len=*), intent(in) :: operation  !< Operation description for
      !! diagnostics.

      call require(status == nf90_noerr, operation//': '//trim(nf90_strerror(status)))
   end subroutine check_nc

   !> Check that translation preserves the local grid geometry.
   subroutine check_translated_coordinates()
      real(kind=DP), dimension(NX,NY) :: xtranslated
      real(kind=DP), dimension(NX,NY) :: ytranslated
      real(kind=RK), dimension(NX,NY) :: original_x
      real(kind=RK), dimension(NX,NY) :: original_y
      real(kind=RK), dimension(NX,NY) :: translated_x
      real(kind=RK), dimension(NX,NY) :: translated_y

      call reset_coordinates()
      call shift_coordinates(X_VALUES, Y_VALUES, original_x, original_y)
      call require(leverr == 0, 'Original coordinate localization reported an error')
      call reset_coordinates()
      xtranslated = X_VALUES - 99999000.0_DP
      ytranslated = Y_VALUES - 499998000.0_DP
      call shift_coordinates(xtranslated, ytranslated, translated_x, translated_y)
      call require(leverr == 0, 'Translated coordinate localization reported an error')
      call require(all(original_x == translated_x), 'Translation changed local X coordinates')
      call require(all(original_y == translated_y), 'Translation changed local Y coordinates')
   end subroutine check_translated_coordinates

   !> Check origin selection after a missing coordinate pair.
   subroutine check_missing_leading_point(xmissing, ymissing)
      real(kind=RK), intent(in) :: xmissing  !< Missing X coordinate marker.
      real(kind=RK), intent(in) :: ymissing  !< Missing Y coordinate marker.

      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal

      call reset_coordinates()
      excfld(8) = xmissing
      excfld(9) = ymissing
      xread = X_VALUES
      yread = Y_VALUES
      xread(1,1) = real(xmissing, kind=DP)
      yread(1,1) = real(ymissing, kind=DP)
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Paired missing coordinates were rejected')
      call require(xoffs == X_VALUES(1,2), 'Origin did not skip the leading missing pair in X-major order')
      call require(yoffs == Y_VALUES(1,2), 'Wrong Y origin after a leading missing pair')
      call require(xlocal(1,2) == 0.0_RK .and. ylocal(1,2) == 0.0_RK, 'First valid point is not the local origin')
      call require(xlocal(1,1) == excfld(8), 'Missing X coordinate does not match its shifted sentinel')
      call require(ylocal(1,1) == excfld(9), 'Missing Y coordinate does not match its shifted sentinel')
      call require(excfld(8) == real(real(xmissing, kind=DP)-xoffs), 'X sentinel was not shifted once')
      call require(excfld(9) == real(real(ymissing, kind=DP)-yoffs), 'Y sentinel was not shifted once')
      call require(lcoordshift, 'Missing-coordinate case did not mark coordinates localized')
   end subroutine check_missing_leading_point

   !> Check rejection of an unmatched missing-coordinate pair.
   subroutine check_mismatched_missing(missing_x)
      logical, intent(in) :: missing_x  !< Whether only the X component is
      !! missing.

      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal

      call reset_coordinates()
      xread = X_VALUES
      yread = Y_VALUES
      if (missing_x) then
         xread(2,1) = 0.0_DP
      else
         yread(2,1) = 0.0_DP
      end if
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr >= 2, 'Mismatched X/Y missing coordinates were accepted')
      call require(.not. lcoordshift, 'Failed coordinate localization set its success flag')
   end subroutine check_mismatched_missing

   !> Check rejection of a grid containing no valid points.
   subroutine check_no_valid_points()
      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal

      call reset_coordinates()
      xread = 0.0_DP
      yread = 0.0_DP
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr >= 2, 'A grid with no valid coordinates was accepted')
      call require(.not. lxoffs .and. .not. lcoordshift, 'Invalid grid initialized an origin or success flag')
   end subroutine check_no_valid_points

   !> Check preservation of an already initialized origin.
   subroutine check_existing_origin()
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal

      call reset_coordinates()
      xoffs = 100000000.0_DP
      yoffs = 500000000.0_DP
      lxoffs = .true.
      call shift_coordinates(X_VALUES, Y_VALUES, xlocal, ylocal)
      call require(leverr == 0, 'Localization with an existing origin reported an error')
      call require(xoffs == 100000000.0_DP .and. yoffs == 500000000.0_DP, 'Existing origin was replaced')
      call require(all(xlocal == EXPECTED_X+0.125_RK), 'Existing X origin was not respected')
      call require(all(ylocal == EXPECTED_Y+0.875_RK), 'Existing Y origin was not respected')
      call require(lcoordshift, 'Existing-origin case did not mark coordinates localized')
   end subroutine check_existing_origin

   !> Check that repeated initialization releases the old origin.
   subroutine check_initialization_cycle(cycle_number)
      integer, intent(in) :: cycle_number  !< Initialization-cycle number.

      real(kind=DP), dimension(NX,NY) :: xread
      real(kind=DP), dimension(NX,NY) :: yread
      real(kind=DP) :: translation
      real(kind=RK), dimension(NX,NY) :: xlocal
      real(kind=RK), dimension(NX,NY) :: ylocal

      call reset_coordinates()
      translation = real(cycle_number, kind=DP)*100000000.0_DP
      xread = X_VALUES + translation
      yread = Y_VALUES + translation
      call shift_coordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Repeated initialization reported an error')
      call require(xoffs == X_VALUES(1,1)+translation, 'Repeated initialization retained an old X origin')
      call require(yoffs == Y_VALUES(1,1)+translation, 'Repeated initialization retained an old Y origin')
      call require(all(xlocal == EXPECTED_X), 'Repeated initialization changed local X coordinates')
      call require(all(ylocal == EXPECTED_Y), 'Repeated initialization changed local Y coordinates')
      call require(lcoordshift, 'Repeated initialization did not set the localization flag')
   end subroutine check_initialization_cycle

end program test_coordinate_input
