@echo off

echo ======================================================================
cd E:\workshop\projects\ms2_fcsps\analysis\Abaqus_validation\inp_files\AR_100-REAL_1
echo ---------------------------
echo  WORKING in %cd%
echo ---------------------------
call abaqus job=E11 inp=RVE_E11_3D.inp interactive
call abaqus job=E22 inp=RVE_E22_3D.inp interactive
call abaqus job=E33 inp=RVE_E33_3D.inp interactive
call abaqus job=G23 inp=RVE_G23_3D.inp interactive
call abaqus job=G31 inp=RVE_G31_3D.inp interactive
call abaqus job=G12 inp=RVE_G12_3D.inp interactive
call abaqus job=CTE inp=RVE_CTE_3D.inp interactive	

echo FINISHED THE ANALYSIS
pause