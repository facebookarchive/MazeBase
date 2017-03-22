# Always prefer setuptools over distutils
from setuptools import setup, find_packages
# To use a consistent encoding
from codecs import open
from os import path

here = path.abspath(path.dirname(__file__))

# Get the long description from the README file
with open(path.join(here, 'README.md'), encoding='utf-8') as f:
    long_description = f.read()

requirements = ['six']

setup(
    name='mazebase',
    version='0.0.1',
    description='Game based library for reinforcement learning',
    long_description=long_description,
    url='https://github.com/facebook/mazebase',
    author='Nantas Nardelli',
    author_email='nantas@robots.ox.ac.uk',
    license='BSD',
    classifiers=[
        # TODO change when we are sure the library is solid
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Science/Research',
        'Topic :: Scientific/Engineering :: Artificial Intelligence',
        'License :: OSI Approved :: BSD License',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.5',
    ],
    keywords='reinforcement-learning machine-learning artificial-intelligence',
    package_data={'mazebase': ['images/*.*'], },
    package_dir={'mazebase': 'py/mazebase'},
    packages=find_packages('py/'),
    install_requires=requirements,
    extras_require={}, )
