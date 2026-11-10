! Exercise SWAN's coordinate reader and localization using real input files.
program test_coordinate_input
   use SwanCoordinateInput, only: SwanReadCoordArray, SwanShiftCoordinates
   use HRExtensions, only: swn_hre_readcoordarray
   use netcdf
   use ocpcomm4, only: ltrace, itest, printf, prtest, leverr, maxerr, iunmin, iunmax
   use swcomm2, only: numgrd, xoffs, yoffs, lxoffs, lcoordshift, excfld
   use m_parall, only: parll, iammaster, inode
   implicit none

   integer, parameter :: nx = 3, ny = 2, data_unit = 31, log_unit = 32
   double precision, parameter :: xvalues(nx,ny) = reshape([ &
      100000000.125d0, 100000020.375d0, 100000040.625d0, &
      100000001.250d0, 100000021.500d0, 100000041.750d0], [nx,ny])
   double precision, parameter :: yvalues(nx,ny) = reshape([ &
      500000000.875d0, 500000002.125d0, 500000003.375d0, &
      500000031.500d0, 500000032.750d0, 500000034.000d0], [nx,ny])
   real, parameter :: expected_x(nx,ny) = reshape([ &
      0.0, 20.25, 40.5, 1.125, 21.375, 41.625], [nx,ny])
   real, parameter :: expected_y(nx,ny) = reshape([ &
      0.0, 1.25, 2.5, 30.625, 31.875, 33.125], [nx,ny])
   integer :: layout, format_kind, cycle_number

   open(unit=log_unit, status='scratch', form='formatted')
   ltrace = .false.
   itest = 0
   printf = log_unit
   prtest = log_unit
   leverr = 0
   maxerr = 3
   parll = .false.
   iammaster = .true.
   inode = 1

   do format_kind = 0, 1
      do layout = 1, 6
         call check_formatted(layout, format_kind)
      end do
   end do
   do layout = 1, 6
      call check_unformatted(layout)
   end do
   call check_unformatted_scaling()
   call check_invalid_unit(0, 0)
   call check_invalid_unit(-1, -1)
   call check_series()
   call check_netcdf()
   call check_netcdf_missing_and_packed()
   call check_translated_coordinates()
   call check_missing_leading_point(0.0, 0.0)
   call check_missing_leading_point(-999.0, -888.0)
   call check_mismatched_missing(.true.)
   call check_mismatched_missing(.false.)
   call check_no_valid_points()
   call check_existing_origin()
   do cycle_number = 1, 2
      call check_initialization_cycle(cycle_number)
   end do

   close(log_unit)
   write(*, '(a)') 'PASS SWAN coordinate input and localization'

contains

   subroutine require(condition, message)
      logical, intent(in) :: condition
      character(len=*), intent(in) :: message

      if (.not. condition) then
         write(*, '(a,a)') 'FAIL: ', message
         rewind(log_unit)
         call print_diagnostics()
         error stop 1
      end if
   end subroutine require

   subroutine print_diagnostics()
      character(len=256) :: line
      integer :: read_status

      do
         read(log_unit, '(a)', iostat=read_status) line
         if (read_status /= 0) then
            exit
         end if
         write(*, '(a)') trim(line)
      end do
   end subroutine print_diagnostics

   subroutine reset_coordinates()
      leverr = 0
      xoffs = 0.d0
      yoffs = 0.d0
      lxoffs = .false.
      lcoordshift = .false.
      excfld(8:9) = 0.0
   end subroutine reset_coordinates

   subroutine write_vector(values, format_kind)
      double precision, intent(in) :: values(:)
      integer, intent(in) :: format_kind

      if (format_kind < 0) then
         write(data_unit) real(values)
      else if (format_kind == 0) then
         write(data_unit, *) values
      else
         write(data_unit, '(6f24.8)') values
      end if
   end subroutine write_vector

   subroutine write_field(values, layout, format_kind)
      double precision, intent(in) :: values(nx,ny)
      integer, intent(in) :: layout, format_kind
      integer :: row, column

      if (format_kind < 0) then
         write(data_unit) 'coordinate field'
      else
         write(data_unit, '(a)') 'coordinate field'
      end if
      select case (layout)
      case (1)
         do row = ny, 1, -1
            call write_vector(values(:,row), format_kind)
         end do
      case (2)
         call write_vector([values(:,2), values(:,1)], format_kind)
      case (3)
         do row = 1, ny
            call write_vector(values(:,row), format_kind)
         end do
      case (4)
         call write_vector(reshape(values, [nx*ny]), format_kind)
      case (5)
         do column = 1, nx
            call write_vector(values(column,:), format_kind)
         end do
      case (6)
         call write_vector([values(1,:), values(2,:), values(3,:)], format_kind)
      end select
   end subroutine write_field

   subroutine read_pair(layout, format_kind, factor, xread, yread)
      integer, intent(in) :: layout, format_kind
      real, intent(in) :: factor
      double precision, intent(out) :: xread(nx,ny), yread(nx,ny)
      integer :: data_source, file_list, read_layout

      data_source = data_unit
      file_list = 0
      read_layout = layout
      xread = 0.d0
      yread = 0.d0
      call SwanReadCoordArray(xread, nx, ny, file_list, data_source, &
                             format_kind, '(6f24.8)', read_layout, factor, 1, 0)
      call require(leverr == 0, 'Reading X coordinates reported an error')
      call SwanReadCoordArray(yread, nx, ny, file_list, data_source, &
                             format_kind, '(6f24.8)', read_layout, factor, 1, 0)
      call require(leverr == 0, 'Reading Y coordinates reported an error')
      call require(read_layout == layout, 'Reader changed a successful layout code')
   end subroutine read_pair

   subroutine check_formatted(layout, format_kind)
      integer, intent(in) :: layout, format_kind
      real :: factor, xlocal(nx,ny), ylocal(nx,ny)
      double precision :: xread(nx,ny), yread(nx,ny)

      call reset_coordinates()
      factor = real(format_kind + 1)
      open(unit=data_unit, status='scratch', form='formatted')
      call write_field(xvalues, layout, format_kind)
      call write_field(yvalues, layout, format_kind)
      rewind(data_unit)
      call read_pair(layout, format_kind, factor, xread, yread)
      close(data_unit)
      call require(all(xread == xvalues*dble(factor)), 'Formatted X input lost precision or ordering')
      call require(all(yread == yvalues*dble(factor)), 'Formatted Y input lost precision or ordering')
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Formatted coordinate localization reported an error')
      call require(lxoffs .and. lcoordshift, 'Coordinate initialization flags were not set')
      call require(xoffs == xvalues(1,1)*dble(factor), 'X origin lost double precision')
      call require(yoffs == yvalues(1,1)*dble(factor), 'Y origin lost double precision')
      call require(all(xlocal == expected_x*factor), 'Localized X coordinates lost small distances')
      call require(all(ylocal == expected_y*factor), 'Localized Y coordinates lost small distances')
   end subroutine check_formatted

   subroutine check_unformatted(layout)
      integer, intent(in) :: layout
      double precision :: xbinary(nx,ny), ybinary(nx,ny), xread(nx,ny), yread(nx,ny)

      call reset_coordinates()
      xbinary = dble(expected_x) + 10.125d0
      ybinary = dble(expected_y) + 20.875d0
      open(unit=data_unit, status='scratch', form='unformatted')
      call write_field(xbinary, layout, -1)
      call write_field(ybinary, layout, -1)
      rewind(data_unit)
      call read_pair(layout, -1, 0.5, xread, yread)
      close(data_unit)
      call require(all(xread == xbinary*0.5d0), 'Legacy REAL binary X input changed')
      call require(all(yread == ybinary*0.5d0), 'Legacy REAL binary Y input changed')
   end subroutine check_unformatted

   subroutine check_unformatted_scaling()
      double precision :: xbinary(nx,ny), ybinary(nx,ny), xread(nx,ny), yread(nx,ny)
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      xbinary = dble(expected_x) + 1.d0
      ybinary = dble(expected_y) + 2.d0
      ! Both neighbors are exactly representable in the legacy REAL file.
      xbinary(2,1) = 1.d0 + 2.d0**(-23)
      open(unit=data_unit, status='scratch', form='unformatted')
      call write_field(xbinary, 4, -1)
      call write_field(ybinary, 4, -1)
      rewind(data_unit)
      call read_pair(4, -1, 1.e8, xread, yread)
      close(data_unit)
      call require(all(xread == xbinary*1.d8), 'Binary X scaling rounded before localization')
      call require(all(yread == ybinary*1.d8), 'Binary Y scaling rounded before localization')
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Scaled binary coordinate localization reported an error')
      call require(xlocal(2,1) == real(11.920928955078125d0), 'Binary scaling lost a represented neighbor separation')
   end subroutine check_unformatted_scaling

   subroutine check_invalid_unit(format_kind, bad_unit)
      integer, intent(in) :: format_kind, bad_unit
      integer :: data_source, read_layout
      double precision :: values(nx,ny)

      call reset_coordinates()
      data_source = bad_unit
      read_layout = 4
      values = 123.d0
      call SwanReadCoordArray(values, nx, ny, 0, data_source, format_kind, &
                             '(6f24.8)', read_layout, 1.0, 0, 0)
      call require(leverr >= 2, 'Invalid coordinate input unit was accepted')
      call require(read_layout == -2, 'Invalid input unit did not return a failed layout code')
   end subroutine check_invalid_unit

   subroutine check_series()
      character(len=*), parameter :: first_file = 'swan_coordinate_series_first.dat'
      character(len=*), parameter :: second_file = 'swan_coordinate_series_second.dat'
      integer :: data_source, read_layout
      double precision :: xread(nx,ny), yread(nx,ny)
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      iunmin = 0
      iunmax = 99999
      open(unit=data_unit, file=first_file, status='replace', form='formatted')
      call write_field(xvalues, 4, 0)
      close(data_unit)
      open(unit=data_unit, file=second_file, status='replace', form='formatted')
      write(data_unit, '(a)') 'new coordinate file header'
      call write_field(yvalues, 4, 0)
      close(data_unit)
      open(unit=33, status='scratch', form='formatted')
      write(33, '(a)') second_file
      rewind(33)
      open(unit=data_unit, file=first_file, status='old', form='formatted')
      data_source = data_unit
      read_layout = 4
      call SwanReadCoordArray(xread, nx, ny, 33, data_source, 0, '(6f24.8)', read_layout, 1.0, 1, 1)
      call require(leverr == 0, 'Reading first coordinate SERIES file reported an error')
      call SwanReadCoordArray(yread, nx, ny, 33, data_source, 0, '(6f24.8)', read_layout, 1.0, 1, 1)
      call require(leverr == 0, 'Coordinate SERIES rollover reported an error')
      close(data_source, status='delete')
      close(33)
      open(unit=data_unit, file=first_file, status='old', form='formatted')
      close(data_unit, status='delete')
      call require(all(xread == xvalues), 'First coordinate SERIES field changed')
      call require(all(yread == yvalues), 'SERIES headers or rollover changed the second field')
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Coordinate SERIES localization reported an error')
      call require(all(xlocal == expected_x), 'Coordinate SERIES changed X distances')
      call require(all(ylocal == expected_y), 'Coordinate SERIES changed Y distances')
   end subroutine check_series

   subroutine check_netcdf()
      character(len=*), parameter :: filename = 'swan_coordinate_input_test.nc'
      integer :: ncid, xdimension, ydimension, xvariable, yvariable
      integer :: data_files(numgrd), xsize(numgrd), ysize(numgrd)
      real :: factors(numgrd), xlocal(nx,ny), ylocal(nx,ny)
      double precision :: times(numgrd), xread(nx,ny), yread(nx,ny)

      call reset_coordinates()
      call check_nc(nf90_create(filename, nf90_clobber, ncid), 'create coordinate NetCDF file')
      call check_nc(nf90_def_dim(ncid, 'x', nx, xdimension), 'define X dimension')
      call check_nc(nf90_def_dim(ncid, 'y', ny, ydimension), 'define Y dimension')
      ! IGR 8/9 use these names in the existing SWAN NetCDF field table.
      call check_nc(nf90_def_var(ncid, 'latitude', nf90_double, [xdimension,ydimension], xvariable), &
                    'define first coordinate variable')
      call check_nc(nf90_def_var(ncid, 'longitude', nf90_double, [xdimension,ydimension], yvariable), &
                    'define second coordinate variable')
      call check_nc(nf90_put_att(ncid, xvariable, '_FillValue', 0.d0), 'define first coordinate missing value')
      call check_nc(nf90_put_att(ncid, yvariable, '_FillValue', 0.d0), 'define second coordinate missing value')
      call check_nc(nf90_enddef(ncid), 'finish coordinate variable definitions')
      call check_nc(nf90_put_var(ncid, xvariable, xvalues), 'write first coordinate variable')
      call check_nc(nf90_put_var(ncid, yvariable, yvalues), 'write second coordinate variable')
      call check_nc(nf90_close(ncid), 'close written coordinate file')
      call check_nc(nf90_open(filename, nf90_nowrite, ncid), 'open coordinate input file')
      data_files = 0
      data_files(8:9) = -ncid
      xsize = nx
      ysize = ny
      times = 0.d0
      factors = 2.0
      xread = 0.d0
      yread = 0.d0
      call swn_hre_readcoordarray(data_files, xread, xsize, ysize, times, factors, 8, filename)
      call require(leverr == 0, 'Reading first NetCDF coordinate variable reported an error')
      call swn_hre_readcoordarray(data_files, yread, xsize, ysize, times, factors, 9, filename)
      call require(leverr == 0, 'Reading second NetCDF coordinate variable reported an error')
      call check_nc(nf90_close(ncid), 'close coordinate input file')
      open(unit=33, file=filename, status='old', access='stream', form='unformatted')
      close(33, status='delete')
      call require(all(xread == 2.d0*xvalues), 'NetCDF X coordinates lost double precision')
      call require(all(yread == 2.d0*yvalues), 'NetCDF Y coordinates lost double precision')
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'NetCDF coordinate localization reported an error')
      call require(all(xlocal == 2.0*expected_x), 'NetCDF localization lost X distances')
      call require(all(ylocal == 2.0*expected_y), 'NetCDF localization lost Y distances')
   end subroutine check_netcdf

   subroutine check_netcdf_missing_and_packed()
      character(len=*), parameter :: filename = 'swan_coordinate_packed_test.nc'
      double precision, parameter :: missing_y = -9999.123456789d0
      double precision, parameter :: packed_scale = 0.00100000006103515625d0, packed_offset = 100000000.125d0
      integer, parameter :: missing_x = -32768
      integer :: ncid, xdimension, ydimension, xvariable, yvariable
      integer :: data_files(numgrd), xsize(numgrd), ysize(numgrd), packed_x(nx,ny)
      real :: factors(numgrd), xlocal(nx,ny), ylocal(nx,ny)
      double precision :: times(numgrd), ydata(nx,ny), xread(nx,ny), yread(nx,ny)
      double precision :: wanted_x(nx,ny), wanted_y(nx,ny)

      call reset_coordinates()
      excfld(8) = -999.0
      excfld(9) = -888.0
      packed_x = nint(expected_x*1024.0)
      packed_x(2,1) = missing_x
      ydata = yvalues
      ydata(2,1) = missing_y
      call check_nc(nf90_create(filename, nf90_clobber, ncid), 'create packed coordinate NetCDF file')
      call check_nc(nf90_def_dim(ncid, 'x', nx, xdimension), 'define packed X dimension')
      call check_nc(nf90_def_dim(ncid, 'y', ny, ydimension), 'define packed Y dimension')
      call check_nc(nf90_def_var(ncid, 'latitude', nf90_int, [xdimension,ydimension], xvariable), &
                    'define packed coordinate variable')
      call check_nc(nf90_def_var(ncid, 'longitude', nf90_double, [xdimension,ydimension], yvariable), &
                    'define double coordinate variable with missing values')
      call check_nc(nf90_put_att(ncid, xvariable, '_FillValue', missing_x), 'define packed missing value')
      call check_nc(nf90_put_att(ncid, xvariable, 'scale_factor', packed_scale), 'define double scale factor')
      call check_nc(nf90_put_att(ncid, xvariable, 'add_offset', packed_offset), 'define double coordinate offset')
      call check_nc(nf90_put_att(ncid, yvariable, '_FillValue', missing_y), 'define double missing value')
      call check_nc(nf90_enddef(ncid), 'finish packed coordinate definitions')
      call check_nc(nf90_put_var(ncid, xvariable, packed_x), 'write packed coordinates')
      call check_nc(nf90_put_var(ncid, yvariable, ydata), 'write double coordinates with a missing value')
      call check_nc(nf90_close(ncid), 'close written packed coordinate file')
      call check_nc(nf90_open(filename, nf90_nowrite, ncid), 'open packed coordinate input')
      data_files = 0
      data_files(8:9) = -ncid
      xsize = nx
      ysize = ny
      times = 0.d0
      factors = 2.0
      call swn_hre_readcoordarray(data_files, xread, xsize, ysize, times, factors, 8, filename)
      call require(leverr == 0, 'Reading packed coordinate input reported an error')
      call swn_hre_readcoordarray(data_files, yread, xsize, ysize, times, factors, 9, filename)
      call require(leverr == 0, 'Reading double missing coordinates reported an error')
      call check_nc(nf90_close(ncid), 'close packed coordinate input')
      open(unit=33, file=filename, status='old', access='stream', form='unformatted')
      close(33, status='delete')
      wanted_x = 2.d0*(dble(packed_x)*packed_scale+packed_offset)
      wanted_y = 2.d0*yvalues
      wanted_x(2,1) = dble(excfld(8))
      wanted_y(2,1) = dble(excfld(9))
      call require(all(abs(xread-wanted_x) < 3.d-8), 'Packed metadata lost precision or scaled its missing value')
      call require(all(yread == wanted_y), 'Double missing value was not mapped to the coordinate sentinel')
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Packed/missing NetCDF coordinate localization reported an error')
      call require(xlocal(2,1) == excfld(8), 'Packed missing X coordinate lost its sentinel')
      call require(ylocal(2,1) == excfld(9), 'Double missing Y coordinate lost its sentinel')
      call require(xlocal(3,2) == real(85.248005203125d0), 'Packed metadata changed local X distances')
      call require(ylocal(3,2) == 2.0*expected_y(3,2), 'Double missing metadata changed local Y distances')
   end subroutine check_netcdf_missing_and_packed

   subroutine check_nc(status, operation)
      integer, intent(in) :: status
      character(len=*), intent(in) :: operation

      call require(status == nf90_noerr, operation//': '//trim(nf90_strerror(status)))
   end subroutine check_nc

   subroutine check_translated_coordinates()
      double precision :: xtranslated(nx,ny), ytranslated(nx,ny)
      real :: original_x(nx,ny), original_y(nx,ny), translated_x(nx,ny), translated_y(nx,ny)

      call reset_coordinates()
      call SwanShiftCoordinates(xvalues, yvalues, original_x, original_y)
      call require(leverr == 0, 'Original coordinate localization reported an error')
      call reset_coordinates()
      xtranslated = xvalues - 99999000.d0
      ytranslated = yvalues - 499998000.d0
      call SwanShiftCoordinates(xtranslated, ytranslated, translated_x, translated_y)
      call require(leverr == 0, 'Translated coordinate localization reported an error')
      call require(all(original_x == translated_x), 'Translation changed local X coordinates')
      call require(all(original_y == translated_y), 'Translation changed local Y coordinates')
   end subroutine check_translated_coordinates

   subroutine check_missing_leading_point(xmissing, ymissing)
      real, intent(in) :: xmissing, ymissing
      double precision :: xread(nx,ny), yread(nx,ny)
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      excfld(8) = xmissing
      excfld(9) = ymissing
      xread = xvalues
      yread = yvalues
      xread(1,1) = dble(xmissing)
      yread(1,1) = dble(ymissing)
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Paired missing coordinates were rejected')
      call require(xoffs == xvalues(1,2), 'Origin did not skip the leading missing pair in X-major order')
      call require(yoffs == yvalues(1,2), 'Wrong Y origin after a leading missing pair')
      call require(xlocal(1,2) == 0.0 .and. ylocal(1,2) == 0.0, 'First valid point is not the local origin')
      call require(xlocal(1,1) == excfld(8), 'Missing X coordinate does not match its shifted sentinel')
      call require(ylocal(1,1) == excfld(9), 'Missing Y coordinate does not match its shifted sentinel')
      call require(excfld(8) == real(dble(xmissing)-xoffs), 'X sentinel was not shifted once')
      call require(excfld(9) == real(dble(ymissing)-yoffs), 'Y sentinel was not shifted once')
      call require(lcoordshift, 'Missing-coordinate case did not mark coordinates localized')
   end subroutine check_missing_leading_point

   subroutine check_mismatched_missing(missing_x)
      logical, intent(in) :: missing_x
      double precision :: xread(nx,ny), yread(nx,ny)
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      xread = xvalues
      yread = yvalues
      if (missing_x) then
         xread(2,1) = 0.d0
      else
         yread(2,1) = 0.d0
      end if
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr >= 2, 'Mismatched X/Y missing coordinates were accepted')
      call require(.not. lcoordshift, 'Failed coordinate localization set its success flag')
   end subroutine check_mismatched_missing

   subroutine check_no_valid_points()
      double precision :: xread(nx,ny), yread(nx,ny)
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      xread = 0.d0
      yread = 0.d0
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr >= 2, 'A grid with no valid coordinates was accepted')
      call require(.not. lxoffs .and. .not. lcoordshift, 'Invalid grid initialized an origin or success flag')
   end subroutine check_no_valid_points

   subroutine check_existing_origin()
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      xoffs = 100000000.d0
      yoffs = 500000000.d0
      lxoffs = .true.
      call SwanShiftCoordinates(xvalues, yvalues, xlocal, ylocal)
      call require(leverr == 0, 'Localization with an existing origin reported an error')
      call require(xoffs == 100000000.d0 .and. yoffs == 500000000.d0, 'Existing origin was replaced')
      call require(all(xlocal == expected_x+0.125), 'Existing X origin was not respected')
      call require(all(ylocal == expected_y+0.875), 'Existing Y origin was not respected')
      call require(lcoordshift, 'Existing-origin case did not mark coordinates localized')
   end subroutine check_existing_origin

   subroutine check_initialization_cycle(cycle_number)
      integer, intent(in) :: cycle_number
      double precision :: xread(nx,ny), yread(nx,ny), translation
      real :: xlocal(nx,ny), ylocal(nx,ny)

      call reset_coordinates()
      translation = dble(cycle_number)*100000000.d0
      xread = xvalues + translation
      yread = yvalues + translation
      call SwanShiftCoordinates(xread, yread, xlocal, ylocal)
      call require(leverr == 0, 'Repeated initialization reported an error')
      call require(xoffs == xvalues(1,1)+translation, 'Repeated initialization retained an old X origin')
      call require(yoffs == yvalues(1,1)+translation, 'Repeated initialization retained an old Y origin')
      call require(all(xlocal == expected_x), 'Repeated initialization changed local X coordinates')
      call require(all(ylocal == expected_y), 'Repeated initialization changed local Y coordinates')
      call require(lcoordshift, 'Repeated initialization did not set the localization flag')
   end subroutine check_initialization_cycle

end program test_coordinate_input
