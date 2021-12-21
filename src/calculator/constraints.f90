!================================================================================!
! This file is part of crest.
!
! Copyright (C) 2021 - 2022 Philipp Pracht
!
! crest is free software: you can redistribute it and/or modify it under
! the terms of the GNU Lesser General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! crest is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU Lesser General Public License for more details.
!
! You should have received a copy of the GNU Lesser General Public License
! along with crest.  If not, see <https://www.gnu.org/licenses/>.
!================================================================================!

!====================================================!
! a small module for constraining potentials
!====================================================!

module constraints

  use iso_fortran_env,only:wp => real64
  implicit none

  !=========================================================================================!
  !--- private module variables and parameters
  private
  integer :: i,j,k,l,ich,och,io
  logical :: ex

  !--- some constants and name mappings
  real(wp),parameter :: bohr = 0.52917726_wp
  real(wp),parameter :: autokcal = 627.509541_wp
  real(wp),parameter :: kB = 3.166808578545117e-06_wp !in Eh/K
  real(wp),parameter :: pi = 3.14159265359_wp
  real(wp),parameter :: deg = 180.0_wp / pi ! 1 rad in degrees
  real(wp),parameter :: fcdefault = 0.01_wp
  real(wp),parameter :: Tdefault = 298.15_wp

  !>--- constrain types
  integer,parameter :: bond = 1
  integer,parameter :: angle = 2
  integer,parameter :: dihedral = 3
  integer,parameter :: wall = 4
  integer,parameter :: wall_fermi = 5
  integer,parameter :: box = 6
  integer,parameter :: box_fermi = 7

  integer,parameter :: pharmonic = 1
  integer,parameter :: plogfermi = 2

  public :: constraint
  !=====================================================!
  type :: constraint

    integer :: type = 0
    integer :: subtype = pharmonic
    integer :: n = 0
    integer,allocatable :: atms(:)
    real(wp),allocatable :: ref(:)
    real(wp),allocatable :: fc(:)

  contains
    procedure :: print => print_constraint
    procedure :: deallocate => constraint_deallocate
    procedure :: bondconstraint => create_bond_constraint
    generic,public :: sphereconstraint => create_sphere_constraint,create_sphere_constraint_all
    procedure,private :: create_sphere_constraint,create_sphere_constraint_all
    procedure :: angleconstraint => create_angle_constraint
    procedure :: dihedralconstraint => create_dihedral_constraint
  end type constraint
  !=====================================================!

  public :: calc_constraint

contains
!========================================================================================!
  subroutine calc_constraint(n,xyz,constr,energy,grd)
    implicit none
    integer,intent(in) :: n
    real(wp),intent(in) :: xyz(3,n)
    type(constraint) :: constr

    real(wp),intent(out) :: energy
    real(wp),intent(out) :: grd(3,n)

    energy = 0.0_wp
    grd = 0.0_wp

    select case (constr%type)
    case (bond)
      call bond_constraint(n,xyz,constr,energy,grd)
    case (angle)
      call angle_constraint(n,xyz,constr,energy,grd)
    case (dihedral)
      call dihedral_constraint(n,xyz,constr,energy,grd)
    case (wall,wall_fermi)
      call wall_constraint(n,xyz,constr,energy,grd,constr%type)
    case (box)

    case (box_fermi)

    case default
      return
    end select

    return
  end subroutine calc_constraint

  subroutine print_constraint(self)
    implicit none
    class(constraint) :: self
    character(len=64) :: art
    character(len=64) :: atoms
    character(len=258) :: values
    character(len=10) :: atm

    if (self%type == 0) return
    select case (self%type)
    case (bond)
      art = 'distance'
      write (atoms,'(1x,"atoms:",1x,i0,",",i0)') self%atms(1:2)
      write (values,'(" d=",f8.2,1x,"k=",f8.5)') self%ref(1),self%fc(1)
    case (angle)
      art = 'angle'
      write (atoms,'(1x,"atoms:",1x,i0,",",i0,",",i0)') self%atms(1:3)
      write (values,'(" deg=",f6.2,1x,"k=",f8.5)') self%ref(1) * deg,self%fc(1)
    case (dihedral)
      art = 'dihedral'
      write (atoms,'(1x,"atoms:",1x,i0,",",i0,",",i0,",",i0)') self%atms(1:4)
      write (values,'(" deg=",f6.2,1x,"k=",f8.5)') self%ref(1) * deg,self%fc(1)
    case (wall)
      art = 'wall'
      write (atoms,'(1x,"atoms:",1x,i0,a)') self%n,'/all'
      write (values,'(" radii=",3f12.5," k=",f8.5,1x,"exp=",f5.2)') self%ref(1:3),self%fc(1:2)
    case (wall_fermi)
      art = 'wall_fermi'
      write (atoms,'(1x,"atoms:",1x,i0,a)') self%n,'/all'
      write (values,'(" radii=",3f12.5," k=",f8.5,1x,"exp=",f5.2)') self%ref(1:3),self%fc(1:2)
    case default
      art = 'none'
      atoms = 'none'
      values = ' '
    end select
    write (*,'(a,a,a,a,1x,a)') ' constraint: ',trim(art),trim(atoms),trim(values)

    return
  end subroutine print_constraint

!========================================================================================!
! subroutien constraint_deallocate
! reset and deallocate all data of a given constraint object
  subroutine constraint_deallocate(self)
    implicit none
    class(constraint) :: self
    if (allocated(self%atms)) deallocate (self%atms)
    if (allocated(self%fc)) deallocate (self%atms)
    if (allocated(self%ref)) deallocate (self%ref)
    self%type = 0
    self%subtype = pharmonic
    self%n = 0
    return
  end subroutine constraint_deallocate

!========================================================================================!
! subroutien create_bond_constraint

  subroutine create_bond_constraint(self,i,j,d,k)
    implicit none
    class(constraint) :: self
    integer,intent(in) :: i,j
    real(wp),intent(in) :: d
    real(wp),optional :: k

    call self%deallocate()
    self%type = bond
    self%n = 2
    allocate (self%atms(2))
    allocate (self%fc(1),source=fcdefault)
    allocate (self%ref(1))
    self%atms(1) = i
    self%atms(2) = j
    self%ref(1) = d
    if (present(k)) then
      self%fc(1) = k
    end if
    return
  end subroutine create_bond_constraint

!========================================================================================!
! constrain the distance between two atoms A...B
! by an harmonic potential V(r) = 1/2kr²
  subroutine bond_constraint(n,xyz,constr,energy,grd)
    implicit none
    integer,intent(in) :: n
    real(wp),intent(in) :: xyz(3,n)
    type(constraint) :: constr

    real(wp),intent(out) :: energy
    real(wp),intent(out) :: grd(3,n)
    integer :: iat,jat
    real(wp) :: a,b,c,x
    real(wp) :: dist,ref,k,dum
    real(wp) :: T,beta

    energy = 0.0_wp
    grd = 0.0_wp

    if (constr%n /= 2) return
    if (.not. allocated(constr%atms)) return
    if (.not. allocated(constr%ref)) return
    if (.not. allocated(constr%fc)) return

    iat = constr%atms(1)
    jat = constr%atms(2)
    a = xyz(1,iat) - xyz(1,jat)
    b = xyz(2,iat) - xyz(2,jat)
    c = xyz(3,iat) - xyz(3,jat)
    dist = sqrt(a**2 + b**2 + c**2)
    ref = constr%ref(1)
    k = constr%fc(1)

    x = dist - ref
    select case (constr%subtype)
    case (pharmonic)
      energy = 0.5_wp * k * (x)**2
      dum = k * x
    case (plogfermi)
      energy = kb * T * log(1.0_wp + exp(beta * x))
      dum = (kb * T * beta * exp(beta * x)) / (exp(beta * x) + 1.0_wp)
    end select

    grd(1,iat) = dum * (a / dist)
    grd(2,iat) = dum * (b / dist)
    grd(3,iat) = dum * (c / dist)
    grd(1,jat) = -grd(1,iat)
    grd(2,jat) = -grd(2,iat)
    grd(3,jat) = -grd(3,iat)

    return
  end subroutine bond_constraint

!========================================================================================!
! subroutien create_angle_constraint
  subroutine create_angle_constraint(self,a,b,c,d,k)
    implicit none
    class(constraint) :: self
    integer,intent(in) :: a,b,c
    real(wp),intent(in) :: d ! constrain angle in degrees
    real(wp),optional :: k
    real(wp) :: dum,d2
    call self%deallocate()
    self%type = angle
    self%n = 3
    allocate (self%atms(3))
    allocate (self%fc(1),source=fcdefault)
    allocate (self%ref(1))
    self%atms(1) = a
    self%atms(2) = b
    self%atms(3) = c
    d2 = abs(d)
    if (d2 > 360.0_wp) then
      dum = d2
      do
        dum = dum - 360.0_wp
        if (dum < 360.0_wp) then
          d2 = dum
          exit
        end if
      end do
    end if
    if (d2 > 180.0_wp) then
      d2 = 360.0_wp - d2
    end if
    self%ref(1) = d2 / deg !reference in rad
    if (present(k)) then
      self%fc(1) = k
    end if
    return
  end subroutine create_angle_constraint

!========================================================================================!
! subroutine angle_constraint
! constrain angle between atoms A and C, connected via a central atom B:  A-B-C
! using a harmonic potential
  subroutine angle_constraint(n,xyz,constr,energy,grd)
    implicit none
    integer,intent(in) :: n
    real(wp),intent(in) :: xyz(3,n)
    type(constraint) :: constr
    real(wp),intent(out) :: energy
    real(wp),intent(out) :: grd(3,n)
    integer :: i,iat,jat,kat
    real(wp) :: A(3),B(3),C(3)
    real(wp) :: r1(3),r2(3)
    real(wp) :: angle,k,ref,p,d,l1,l2
    real(wp) :: dinv,dum,x,T,beta
    real(wp) :: dadA(3),dadB(3),dadC(3)

    energy = 0.0_wp
    grd = 0.0_wp

    if (constr%n /= 3) return
    if (.not. allocated(constr%atms)) return
    if (.not. allocated(constr%ref)) return
    if (.not. allocated(constr%fc)) return

    ref = constr%ref(1)
    k = constr%fc(1)
    iat = constr%atms(1)
    jat = constr%atms(2)
    kat = constr%atms(3)
    A = xyz(:,iat)
    B = xyz(:,jat)
    C = xyz(:,kat)
    call angle_and_derivatives(A,B,C,angle,dadA,dadB,dadC)

    x = angle - ref
    select case (constr%subtype)
    case (pharmonic) !> harmonic potential
      energy = 0.5_wp * k * (x)**2
      dum = k * (x)
    case (plogfermi) !> logfermi potential
      energy = kb * T * log(1.0_wp + exp(beta * x))
      dum = (kb * T * beta * exp(beta * x)) / (exp(beta * x) + 1.0_wp)
    end select

    grd(1,iat) = dum * dadA(1)
    grd(2,iat) = dum * dadA(2)
    grd(3,iat) = dum * dadA(3)
    grd(1,jat) = dum * dadB(1)
    grd(2,jat) = dum * dadB(2)
    grd(3,jat) = dum * dadB(3)
    grd(1,kat) = dum * dadC(1)
    grd(2,kat) = dum * dadC(2)
    grd(3,kat) = dum * dadC(3)

    return
  end subroutine angle_constraint

  subroutine angle_and_derivatives(A,B,C,angle,dadA,dadB,dadC)
    implicit none
    real(wp),intent(in) :: A(3),B(3),C(3) !> points spanning the angle
    real(wp),intent(out) :: angle !> the angle in rad
    real(wp),intent(out) :: dadA(3),dadB(3),dadC(3) !> Cartesian derivatives
    real(wp) :: r1(3),r2(3)
    real(wp) :: p,d,l1,l2
    real(wp) :: dinv,dum

    angle = 0.0_wp
    dadA = 0.0_wp
    dadB = 0.0_wp
    dadC = 0.0_wp

    r1 = A - B
    r2 = C - B
    l1 = rlen(r1)
    l2 = rlen(r2)
    p = dot(r1,r2)
    d = p / (l1 * l2)
    angle = acos(d)
    if (angle < 1d-6 .or. (pi - angle) < 1d-6) then
      dadA(:) = (1.0_wp / l2) * sin(acos(r2(:) / l2))
      dadC(:) = (1.0_wp / l1) * sin(acos(r1(:) / l1))
      if ((pi - angle) < 1d-6) then
        dadA = -dadA
        dadC = -dadC
      end if
    else
      dinv = 1.0_wp / sqrt(1.0_wp - d**2)
      dadA(:) = -dinv * (r2(:) * l1 * l2 - p * (l2 / l1) * r1(:)) / (l1**2 * l2**2)
      dadC(:) = -dinv * (r1(:) * l1 * l2 - p * (l1 / l2) * r2(:)) / (l1**2 * l2**2)
    end if
    dadB = -dadA - dadC

    return
  end subroutine angle_and_derivatives

  real(wp) function rlen(r)
    implicit none
    real(wp) :: r(3)
    rlen = 0.0_wp
    rlen = r(1)**2 + r(2)**2 + r(3)**2
    rlen = sqrt(rlen)
    return
  end function rlen
  real(wp) function dot(r1,r2)
    implicit none
    real(wp) :: r1(3),r2(3)
    dot = 0.0_wp
    dot = r1(1) * r2(1) + r1(2) * r2(2) + r1(3) * r2(3)
    return
  end function dot
  subroutine cross(r1,r2,r3)
    implicit none
    real(wp) :: r1(3),r2(3)
    real(wp) :: r3(3)
    r3 = 0.0_wp
    r3(1) = r1(2) * r2(3) - r1(3) * r2(2)
    r3(2) = r1(3) * r2(1) - r1(1) * r2(3)
    r3(3) = r1(1) * r2(2) - r1(2) * r2(1)
    return
  end subroutine cross

!========================================================================================!
! subroutien create_dihedral_constraint
  subroutine create_dihedral_constraint(self,a,b,c,d,ref,k)
    implicit none
    class(constraint) :: self
    integer,intent(in) :: a,b,c,d
    real(wp),intent(in) :: ref ! constrain angle in degrees
    real(wp),optional :: k
    real(wp) :: dum,d2,sig
    call self%deallocate()
    self%type = dihedral
    self%n = 4
    allocate (self%atms(4))
    allocate (self%fc(1),source=fcdefault)
    allocate (self%ref(1))
    self%atms(1) = a
    self%atms(2) = b
    self%atms(3) = c
    self%atms(4) = d

    d2 = ref
    sig = sign(1.0_wp,ref)
    if (abs(d2) > 360.0_wp) then
      dum = abs(d2)
      do
        dum = dum - 360.0_wp
        if (dum < 360.0_wp) then
          d2 = dum
          exit
        end if
      end do
      d2 = d2 * sig
    end if
    if (d2 > 180.0_wp) then
      d2 = d2 - 360.0_wp
    end if
    if (d2 < -180.0_wp) then
      d2 = d2 + 360.0_wp
    end if
    self%ref(1) = d2 / deg !reference in rad
    if (present(k)) then
      self%fc(1) = k
    end if
    return
  end subroutine create_dihedral_constraint
!========================================================================================!
! subroutine dihedral_constraint
! constrain dihedral angle spanned by atoms A-B-C-D
! using a harmonic potential
  subroutine dihedral_constraint(n,xyz,constr,energy,grd)
    implicit none
    integer,intent(in) :: n
    real(wp),intent(in) :: xyz(3,n)
    type(constraint) :: constr
    real(wp),intent(out) :: energy
    real(wp),intent(out) :: grd(3,n)
    integer :: i,iat,jat,kat,lat
    real(wp) :: A(3),B(3),C(3),D(3)
    real(wp) :: N1(3),N2(3),Nzero(3)
    real(wp) :: rab(3),rcb(3),rdc(3),na,nb,nc
    real(wp) :: dangle,k,ref,p,l1,l2
    real(wp) :: dinv,dum,x,T,beta
    real(wp) :: dadN1(3),dadN2(3),dad0(3)
    real(wp) :: sig,dDdr(3)

    energy = 0.0_wp
    grd = 0.0_wp

    if (constr%n /= 4) return
    if (.not. allocated(constr%atms)) return
    if (.not. allocated(constr%ref)) return
    if (.not. allocated(constr%fc)) return

    ref = constr%ref(1)
    k = constr%fc(1)
    iat = constr%atms(1)
    jat = constr%atms(2)
    kat = constr%atms(3)
    lat = constr%atms(4)
    A = xyz(:,iat)
    B = xyz(:,jat)
    C = xyz(:,kat)
    D = xyz(:,lat)
    Nzero = 0.0_wp
    !> vectors spanning the planes (A,B,C) and (D,C,B)
    rab = A - B
    rcb = C - B
    rdc = D - C
    !> for some reason the normalization breaks everything. thanks for nothing.
    !call norml(rab)
    !call norml(rcb)
    !call norml(rdc)
    !> get the two normal vectors N1 and N2 for the two planes
    call cross(rab,rcb,N1)
    call cross(rdc,rcb,N2)
    p = dot(N1,rdc)
    sig = -sign(1.0_wp,p) 
    call angle_and_derivatives(N1,Nzero,N2,dangle,dadN1,dad0,dadN2)
    dangle = sig * dangle

    x = dangle - ref
    select case (constr%subtype)
    case (pharmonic) !> harmonic potential
      energy = 0.5_wp * k * (x)**2
      dum = k * (x)
    case (plogfermi) !> logfermi potential
      energy = kb * T * log(1.0_wp + exp(beta * x))
      dum = (kb * T * beta * exp(beta * x)) / (exp(beta * x) + 1.0_wp)
    end select

    dDdr(1) = sig * (dadN1(2) * (B(3) - C(3)) + dadN1(3) * (C(2) - B(2)))
    dDdr(2) = sig * (dadN1(1) * (C(3) - B(3)) + dadN1(3) * (B(1) - C(1)))
    dDdr(3) = sig * (dadN1(1) * (B(2) - C(2)) + dadN1(2) * (C(1) - B(1)))
    grd(1,iat) = dum * dDdr(1)
    grd(2,iat) = dum * dDdr(2)
    grd(3,iat) = dum * dDdr(3)
    dDdr(1) = sig * (dadN1(2) * (C(3) - A(3)) + dadN1(3) * (A(2) - C(2)) &
    &       + dadN2(2) * (C(3) - D(3)) + dadN2(3) * (D(2) - C(2)))
    dDdr(2) = sig * (dadN1(1) * (A(3) - C(3)) + dadN1(3) * (C(1) - A(1)) &
    &       + dadN2(1) * (D(3) - C(3)) + dadN2(3) * (C(1) - D(1)))
    dDdr(3) = sig * (dadN1(1) * (C(2) - A(2)) + dadN1(2) * (A(1) - C(1)) &
    &       + dadN2(1) * (C(2) - D(2)) + dadN2(2) * (D(1) - C(1)))
    grd(1,jat) = dum * dDdr(1)
    grd(2,jat) = dum * dDdr(2)
    grd(3,jat) = dum * dDdr(3)
    dDdr(1) = sig * (dadN1(2) * (A(3) - B(3)) + dadN1(3) * (B(2) - A(2)) &
    &       + dadN2(2) * (D(3) - B(3)) + dadN2(3) * (B(2) - D(2)))
    dDdr(2) = sig * (dadN1(1) * (B(3) - A(3)) + dadN1(3) * (A(1) - B(1)) &
    &       + dadN2(1) * (B(3) - D(3)) + dadN2(3) * (D(1) - B(1)))
    dDdr(3) = sig * (dadN1(1) * (A(2) - B(2)) + dadN1(2) * (B(1) - A(1)) &
    &       + dadN2(1) * (D(2) - B(2)) + dadN2(2) * (B(1) - D(1)))
    grd(1,kat) = dum * dDdr(1)
    grd(2,kat) = dum * dDdr(2)
    grd(3,kat) = dum * dDdr(3)
    dDdr(1) = sig * (dadN2(2) * (B(3) - C(3)) + dadN2(3) * (C(2) - B(2)))
    dDdr(2) = sig * (dadN2(1) * (C(3) - B(3)) + dadN2(3) * (B(1) - C(1)))
    dDdr(3) = sig * (dadN2(1) * (B(2) - C(2)) + dadN2(2) * (C(1) - B(1)))
    grd(1,lat) = dum * dDdr(1)
    grd(2,lat) = dum * dDdr(2)
    grd(3,lat) = dum * dDdr(3)

    return
  contains
    subroutine norml(r)
       implicit none
       real(wp) :: r(3)
       real(wp) :: dum
       integer :: i 
       dum = 0.0_wp
       do i=1,3
       dum = dum + r(i)**2
       enddo
       r = r/sqrt(dum)
       return
    end subroutine norml
  subroutine dphidr(nat,xyz,i,j,k,l,phi,dphidri,dphidrj,dphidrk,dphidrl)
   !> the torsion derivatives
   implicit none
   !external vecnorm
   integer :: ic,i,j,k,l,nat
   real(wp)&
      &         sinphi,cosphi,onenner,thab,thbc,&
      &         ra(3),rb(3),rc(3),rab(3),rac(3),rbc(3),rbb(3),&
      &         raa(3),rba(3),rapba(3),rapbb(3),rbpca(3),rbpcb(3),&
      &         rapb(3),rbpc(3),na(3),nb(3),nan,nbn,&
      &         dphidri(3),dphidrj(3),dphidrk(3),dphidrl(3),&
      &         xyz(3,nat),phi,vecnorm,nenner,eps,vz

   parameter (eps=1.d-14)

   cosphi=cos(phi)
   sinphi=sin(phi)
   do ic=1,3
      ra(ic)=xyz(ic,j)-xyz(ic,i)
      rb(ic)=xyz(ic,k)-xyz(ic,j)
      rc(ic)=xyz(ic,l)-xyz(ic,k)

      rapb(ic)=ra(ic)+rb(ic)
      rbpc(ic)=rb(ic)+rc(ic)
   end do

   call cross(ra,rb,na)
   call cross(rb,rc,nb)
   !nan=vecnorm(na,3,0)
   nan=sqrt(na(1)**2 + na(2)**2 + na(3)**2)
   !nbn=vecnorm(nb,3,0)
   nbn=sqrt(nb(1)**2 + nb(2)**2 + nb(3)**2)
   nenner=nan*nbn*sinphi
   if (abs(nenner).lt.eps) then
      dphidri=0.0_wp
      dphidrj=0.0_wp
      dphidrk=0.0_wp
      dphidrl=0.0_wp
      onenner=1.0_wp/(nan*nbn)
   else
      onenner=1.0_wp/nenner
   endif

   call cross(na,rb,rab)
   call cross(nb,ra,rba)
   call cross(na,rc,rac)
   call cross(nb,rb,rbb)
   call cross(nb,rc,rbc)
   call cross(na,ra,raa)

   call cross(rapb,na,rapba)
   call cross(rapb,nb,rapbb)
   call cross(rbpc,na,rbpca)
   call cross(rbpc,nb,rbpcb)

   ! ... dphidri
   do ic=1,3
      dphidri(ic)=onenner*(cosphi*nbn/nan*rab(ic)-rbb(ic))

      ! ... dphidrj
      dphidrj(ic)=onenner*(cosphi*(nbn/nan*rapba(ic)&
         &                                +nan/nbn*rbc(ic))&
         &                        -(rac(ic)+rapbb(ic)))
      ! ... dphidrk
      dphidrk(ic)=onenner*(cosphi*(nbn/nan*raa(ic)&
         &                             +nan/nbn*rbpcb(ic))&
         &                        -(rba(ic)+rbpca(ic)))
      ! ... dphidrl
      dphidrl(ic)=onenner*(cosphi*nan/nbn*rbb(ic)-rab(ic))
   end do

 end subroutine dphidr

  end subroutine dihedral_constraint

!========================================================================================!
! subroutien create_sphere_constraint

  subroutine create_sphere_constraint_all(self,n,r,k,alpha,logfermi)
    implicit none
    class(constraint) :: self
    integer,intent(in) :: n
    logical,allocatable :: atms(:)
    real(wp),intent(in) :: r
    real(wp) :: k,alpha
    logical,intent(in) :: logfermi
    integer :: i,c

    allocate (atms(n),source=.true.)
    call create_sphere_constraint(self,n,atms,r,k,alpha,logfermi)
    deallocate (atms)
    return
  end subroutine create_sphere_constraint_all

  subroutine create_sphere_constraint(self,n,atms,r,k,alpha,logfermi)
    implicit none
    class(constraint) :: self
    integer,intent(in) :: n
    logical,intent(in) :: atms(n)
    real(wp),intent(in) :: r
    real(wp) :: k,alpha
    logical,intent(in) :: logfermi
    integer :: i,c

    call self%deallocate()
    if (logfermi) then
      self%type = wall_fermi
    else
      self%type = wall
    end if
    c = count(atms,1)
    self%n = c
    allocate (self%atms(c))
    allocate (self%fc(2),source=fcdefault)
    allocate (self%ref(3),source=r)
    do i = 1,n
      if (atms(i)) self%atms(i) = i
    end do
    self%ref = r
    self%fc(1) = k
    self%fc(2) = alpha
    return
  end subroutine create_sphere_constraint

!========================================================================================!
! constrain atoms within defined wall potentials
! the potentials themselves can be polinomial or logfermi type
  subroutine wall_constraint(n,xyz,constr,energy,grd,subtype)
    implicit none
    integer,intent(in) :: n
    real(wp),intent(in) :: xyz(3,n)
    type(constraint) :: constr
    integer,intent(in) :: subtype
    real(wp),intent(out) :: energy
    real(wp),intent(out) :: grd(3,n)
    integer :: i,iat,jat
    real(wp) :: a,b,c,x,y,z,dx,dy,dz
    real(wp) :: dist,ddist,ref
    real(wp) :: k,alpha,dalpha,T,beta
    real(wp) :: fermi,expo,r(3),w(3)

    energy = 0.0_wp
    grd = 0.0_wp

    if (.not. allocated(constr%atms)) return
    if (.not. allocated(constr%ref)) return
    if (.not. allocated(constr%fc)) return

    do i = 1,n
      iat = constr%atms(i)
      select case (subtype)
      case default
        return
      case (wall)
        k = constr%fc(1)
        alpha = constr%fc(2)
        dalpha = alpha - 1.0_wp
        x = xyz(1,iat)
        y = xyz(2,iat)
        z = xyz(3,iat)
        a = constr%ref(1)
        b = constr%ref(2)
        c = constr%ref(3)
        dist = (x / a)**2 + (y / b)**2 + (z / c)**2
        energy = energy + k * (dist**alpha)
        dx = 2.0_wp * (x / (a**2))
        dy = 2.0_wp * (y / (b**2))
        dz = 2.0_wp * (z / (c**2))
        ddist = k * alpha * (dist**dalpha)
        grd(1,iat) = ddist * dx
        grd(2,iat) = ddist * dy
        grd(3,iat) = ddist * dz
      case (wall_fermi)
        T = constr%fc(1)
        beta = constr%fc(2)
        ref = maxval(constr%ref(1:3))
        w(1:3) = ref / constr%ref(1:3)
        r = w * (xyz(1:3,iat))
        dist = sqrt(sum(r**2))
        expo = exp(beta * (dist - ref))
        fermi = 1.0_wp / (1.0_wp + expo)
        energy = energy + kB * T * log(1.0_wp + expo)
        grd(:,iat) = grd(:,iat) + kB * T * beta * expo * fermi * (r * w) / (dist + 1.0e-14_wp)
      case (box)

      case (box_fermi)

      end select
    end do

    return
  end subroutine wall_constraint

end module constraints