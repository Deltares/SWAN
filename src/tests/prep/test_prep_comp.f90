program test_prep_comp
    use ocpcomm4, only: ltrace
    use swcomm3, only: NUMOBS
    use m_obsta, only: OBSTDAT, OBSTDAT_PTR, OBSTDONE
    use SwanGriddata, only: nverts, nfaces
    use SwanGridobjects, only: gridobject
    implicit none

    type(OBSTDAT), target :: obstacle
    type(OBSTDAT_PTR) :: guard(4), existing(2)
    type(OBSTDAT_PTR), allocatable :: empty(:)
    integer :: i, repeat

    interface
        subroutine SwanPrepComp(cross)
            import OBSTDAT_PTR
            type(OBSTDAT_PTR), intent(inout) :: cross(*)
        end subroutine SwanPrepComp
    end interface

    ltrace = .false.
    nverts = 0
    nfaces = 2
    nullify(gridobject%vert_grid)

    ! A zero-length section exposes entry-time writes without corrupting a heap.
    do i = 1, size(guard)
        guard(i)%ptr => obstacle
    end do
    NUMOBS = 0
    OBSTDONE = .false.
    call SwanPrepComp(guard(2:1))
    do i = 1, size(guard)
        if (.not.associated(guard(i)%ptr, obstacle)) then
            error stop 'Obstacle preparation wrote outside an empty array'
        end if
    end do
    if (OBSTDONE) then
        error stop 'Empty obstacle preparation changed OBSTDONE'
    end if

    ! Later COMPUTE commands must preserve previously found obstacles.
    do i = 1, size(existing)
        existing(i)%ptr => obstacle
    end do
    NUMOBS = 1
    OBSTDONE = .true.
    do repeat = 1, 2
        call SwanPrepComp(existing)
        do i = 1, size(existing)
            if (.not.associated(existing(i)%ptr, obstacle)) then
                error stop 'Repeated preparation cleared an obstacle pointer'
            end if
        end do
        if (.not.OBSTDONE) then
            error stop 'Repeated preparation cleared OBSTDONE'
        end if
    end do

    ! Exercise the actual allocation used by SWMAIN without obstacles.
    NUMOBS = 0
    OBSTDONE = .false.
    allocate(empty(0))
    call SwanPrepComp(empty)
    deallocate(empty)
    print *, 'Obstacle preparation regression passed'
end program test_prep_comp
