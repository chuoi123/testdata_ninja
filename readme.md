# testdata_ninja
Morten Egan <morten@plsql.ninja>

The ultimate test data generator based on PLSQL.

## Summary

This package enables you to easily create test data generators, that you can use for automatic testing and much more.

## Pre-requisites

You need an Oracle database user with the following privileges

- create procedure.
- execute privileges on any functions that are used for the generators.

If you are using the pre-built generators in the package, you are required to install the [RANDOM_NINJA](https://github.com/morten-egan/random_ninja) package.

## Installation

To install the generator package, simply install the following 2 files:

- testdata_ninja.package.sql
- testdata_ninja.package body.sql

## User Guide

### Generator format

The generators that you create are all defined using a simple text based syntax.

The structure of the generator is that for every column in your output you need to define the following:

- Name of the column
- Data type of the column
- The data generator
- Any input arguments to the data generator.

#### Column Name

## Examples
