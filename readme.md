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

### Generator format description

The generators that you create are all defined using a simple text based syntax.

The structure of the generator is that for every column in your output you need to define the following:

- Name of the column
- Data type of the column
- The data generator
- Any input arguments to the data generator.

##### Column Name (required)
The name of the column is just like a column name in a table definition. It follows the same restrictions in terms of reserved words and characters allowed in the name.

##### Data Type (required)
The data type of the column can be most of the oracle data types that are supported. Currently the following data types are tested and verified as working:

- number
- varchar2
- date
- timestamp
- clob
- blob

##### Data Generator (required)
Data generators can be any function that returns a single value in the supported data types. This is the place where you define what data you are going to generate for the output. The data generator also includes a couple of built-in special generators. The types of supported generators are:

- Generated value, where a function returns the value.
- Fixed value, where the value is hard coded.
- Referential generator where the value is generated from a parent table.
- Incremental generator, where the values are unique and always incremented.

##### Input Arguments (optional)
When the data generator is a function, the values for any input parameters can be specified here. You can use the normal oracle notation, so either an ordered comma separated list or named notation where you specify the name of the parameter. This is not a required field in your definition.

### Generator Format Syntax

##### JSON Notation syntax
> This is where the JSON notation will be described.

##### ASCII Text notation syntax
The ASCII notation style is a very simple clear text notation to describe your generator. The field definitions in the notation are separated by the '#' character. So a column definition would be defined like this:

        <column name>#<data type>#<data generator>#<input arguments>

When you have multiple columns in your generator output, each column definition is separated by the '@' character. So a 2 column generator definition would look like this:

        <column1 name>#<data type>#<data generator>#<input arguments>
        @<column2 name>#<data type>#<data generator>#<input arguments>

See below sections for a detailed description of each field definition and the syntax.

###### Column name syntax
The column name field, has to follow the standard Oracle column syntax and rules. So if your version is less than 12.2 there is a 30 character length restriction or else the column name can be 128 characters long.

**Examples:**

*A column with the name "ename"*

    ename#<data type>#<data generator>#<input arguments>

*A column with the name "birth_date"*

    birth_date#<data type>#<data generator>#<input arguments>

*A column with the name "order_amount"*

    order_amount#<data type>#<data generator>#<input arguments>

###### Data type syntax
The data type field has to be a valid Oracle data type. For any data types that require a length specification, you have to specify that as well. For now only the following data types has been verified as working:

- number
- varchar2
- date
- timestamp
- clob
- blob

**Examples:**

*Defining the "ename" column as varchar2(10)*

    ename#varchar2(10)#<data generator>#<input arguments>

*Defining the column birth_date as date data type*

    birth_date#date#<data generator>#<input arguments>

*Defining the column order_amount as number 16,4*

    order_amount#number(16,4)#<data generator>#<input arguments>

## Examples
