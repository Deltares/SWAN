from conan import ConanFile
from conan.tools.files import save


class SWANRecipe(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps"

    def requirements(self):
        self.requires("zlib/[>=1.2.11 <2]")
        self.requires("hdf5/1.14.2")
        self.requires("netcdf/4.9.2")
        self.requires("netcdf-fortran/4.6.2")

    def generate(self):
        save(self, "conan.stamp", "Timestamp of this file is used by CMake to detect if conan.lock has changed since last conan install.")

    def layout(self):
        self.folders.generators = "generators"

    def configure(self):
        self.options["zlib"].shared = True
        self.options["hdf5"].shared = True
        self.options["netcdf"].shared = True
        self.options["netcdf-fortran"].shared = True
        # disable DAP and byterange support, this requires dependencies like libcurl are not needed
        self.options["netcdf"].dap = False
        self.options["netcdf"].byterange = False
        self.options["hdf5"].enable_cxx = False
