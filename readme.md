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

#### JSON Notation syntax
> This is where the JSON notation will be described.

#### ASCII Text notation syntax
The ASCII notation style is a very simple clear text notation to describe your generator. The field definitions in the notation are separated by the '#' character. So a column definition would be defined like this:

        <column name>#<data type>#<data generator>#<input arguments>

When you have multiple columns in your generator output, each column definition is separated by the '@' character. So a 2 column generator definition would look like this:

        <column1 name>#<data type>#<data generator>#<input arguments>
        @<column2 name>#<data type>#<data generator>#<input arguments>

See below sections for a detailed description of each field definition and the syntax.

##### Column name syntax
The column name field, has to follow the standard Oracle column syntax and rules. So if your version is less than 12.2 there is a 30 character length restriction or else the column name can be 128 characters long.

**Examples:**

*A column with the name "ename"*

    ename#<data type>#<data generator>#<input arguments>

*A column with the name "birth_date"*

    birth_date#<data type>#<data generator>#<input arguments>

*A column with the name "order_amount"*

    order_amount#<data type>#<data generator>#<input arguments>

##### Data type syntax
The data type field has to be a valid Oracle data type. For any data types that require a length specification, you have to specify that as well. For now only the following data types has been verified as working:

- number
- varchar2
- date
- timestamp
- clob
- blob

**Examples:**

*Defining the "ename" column as varchar2(150)*

    ename#varchar2(150)#<data generator>#<input arguments>

*Defining the column birth_date as date data type*

    birth_date#date#<data generator>#<input arguments>

*Defining the column order_amount as number*

    order_amount#number#<data generator>#<input arguments>

##### Data generator syntax
This is the field that actually creates our output data. By default it takes the name of a function that the user has execute privileges on. There are also other built-in special generators that can be used for more specific type of data or referential data, in case you want the output to be child data from an already existing parent table.

###### Function data generator
This is the most simple type of generator. Simply write the name of the function that will generate the output. The user that creates the test data generator has to have execute privileges on the function for it to work.

**Examples:**

*Generating random text strings as names for the ename column*

    ename#varchar2(150)#dbms_random.string#<input arguments>

*Setting the birth_date column to a value of sysdate*

    birth_date#date#sysdate#<input arguments>

*Setting order_amount column with a random number*

    order_amount#number#dbms_random.value#<input arguments>

###### Incremental data generator
This data generator is one of the built-in generators. It is used to create either incremental numbers or incremental dates for now. The use case is of course if you need something that can be easily used as a primary key (incremental numbers) or if you are trying to create test data that mimics chronological events (incremental dates).

The format for these generators has a bit more options. They actually have their own fields within the field definition. The way to specify a built-in generator is to use the '^' character as the very first character in the field definition. The syntax for the incremental functions are as below.

*Number incremental function syntax*

    ^numiterate~<start from number>~<increment range start¤increment range end>

The <start from number> and <range of next increment> are not required values. *If you choose not to specify them, the start from number will be 1, and the increment range start will be 1 and increment range end will be 5.* If you choose specify them, they both have to specified and in the correct order.

When you specify the extra options the format has to be followed. So imagine you want to create an incremental number function, that starts with 5 and increments by 1 at a time, you would do it like this:

    ^numiterate~5~1¤1

Or if you wanted to create an incremental number function that starts with 700 and increments with a number between 12 and 56, you would define it like this:

    ^numiterate~700~12¤56

*Date incremental syntax*

    ^datiterate~<start from date>

## Examples
