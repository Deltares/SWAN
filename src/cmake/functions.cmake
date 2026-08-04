# Find all binaries in "targetDir" and set rpath to "rpathValue" in these binaries
# This function is copied from the Delft3D repository
function(set_rpath targetDir rpathValue)
  execute_process(COMMAND find "${targetDir}" -type f -exec bash -c "patchelf --set-rpath '${rpathValue}' $1" _ {} \; -exec echo "patched rpath of: " {} \;)
endfunction(set_rpath)
