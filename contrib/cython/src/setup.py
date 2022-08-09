from setuptools import setup, Extension
from Cython.Build import cythonize

extensions = [
    Extension(
        "*", ["*.pyx"],
        libraries=["portaudio"],
    ),
]

setup(
    ext_modules=\
    cythonize(extensions,
              annotate=True,
              compiler_directives={
                  "language_level": 3,
                  "boundscheck": False,
                  "wraparound": False,
                  "initializedcheck": False,
                  "cdivision": True,
              },
    ),
)
