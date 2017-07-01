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

- [Generator format description](#generator-format-description)
  - [Column Name](#column-name--required)
  - [Data Type](#data-type--required)
  - [Data Generator](#data-generator--required)
  - [Input Arguments](#input-arguments--optional)
- [Generator Format Syntax](#generator-format-syntax)
  - [JSON Notation Syntax](#json-notation-syntax)
  - [ASCII Text Notation Syntax](#ascii-text-notation-syntax)
    - [Column name syntax](#column-name-syntax)
    - [Data type syntax](#data-type-syntax)
    - [Data generator syntax](#data-generator-syntax)
      - [Function data generator](#function-data-generator)
      - [Incremental data generator](#incremental-data-generator)
      - [Referential data generator](#referential-data-generator)
      - [Fixed value data generator](#fixed-value-data-generator)
    - [Input argument syntax](#input-argument-syntax)
- [Auto Input Reference](#auto-input-reference)
- [Building Generators](#building-generators)
- [Using Generators](#using-generators)

### Generator format description

The generators that you create are all defined using a simple text based syntax.

The structure of the generator is that for every column in your output you need to define the following:

- Name of the column
- Data type of the column
- The data generator
- Any input arguments to the data generator.

##### Column Name -required
The name of the column is just like a column name in a table definition. It follows the same restrictions in terms of reserved words and characters allowed in the name.

##### Data Type -required
The data type of the column can be most of the oracle data types that are supported. Currently the following data types are tested and verified as working:

- number
- varchar2
- date
- timestamp
- clob
- blob

##### Data Generator -required
Data generators can be any function that returns a single value in the supported data types. This is the place where you define what data you are going to generate for the output. The data generator also includes a couple of built-in special generators. The types of supported generators are:

- Generated value, where a function returns the value.
- Fixed value, where the value is hard coded.
- Referential generator where the value is generated from a parent table.
- Incremental generator, where the values are unique and always incremented.

##### Input Arguments -optional
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

    ^datiterate~<start from date>~<incremental date element type¤increment range start¤increment range end>

The start from date format has to be 'DDMMYYYY-HH24:MI:SS'. The possible  The start from date and range of next increment are not required values. *If you choose not to specify them, the start date will be sysdate, and the increment element will be minutes and the increment start range will be 1 and the increment end range will be 5.* If you choose to specify them, they both have to be specified and in the correct order.

The possible incremental date elements one can specify, are:

- seconds
- minutes
- hours
- days
- months
- years

One example could be that you wanted to create a date incremental function that incremented the date with 1 minute for every time we used it, and it should start from May 22'nd 1985 at noon. To define that, it would look like this:

    ^datiterate~22051985-12:00:00~minutes¤1¤1

Or if you wanted to create a date incremental that started on June 24 2017, at 13:32 and for every time we referenced the incremental function it should add between 1 and 4 seconds. A date incremental would look like this:

    ^datiterate~24062017-13:32:00~seconds¤1¤4

**Examples:**

*Creating a column called num_pk, that is used as a primary key and increments by 1 for every row generated*

    num_pk#number#^numiterate~1~1¤1#<input arguments>

*Creating a column called event_date, that is used as an incremental event occurrence and increments by 2-7 seconds for every row*

    event_date#date#^datiterate~18042017-08:00:00~seconds¤2¤7#<input arguments>

###### Referential data generator
This is one of the other built-in generators. This generator makes it possible to create values that can used as references in foreign keys. So the basics of the generator is that you refer to an existing table and column that matches your data type, and you define how many child rows you would like for each parent value.

*Reference field syntax*

    £<table name>¤<column name>¤<reference count type>¤<count type format>

For the table name value it has to be a table that the user creating and executing the generator has privileges to access. Column name has to be an actual column name from the table name. For reference count type there are 3 different values:

- *simple* - Where you just define a single number of child rows per parent table.
- *range* - Where for every parent row, you define a range of possible child rows.
- *weighted* - Where you set a weight for every possible number of child rows.

Count type format depends on the value that has been set for the <reference count type>.

- *simple type format* - [single number]
- *range type format* - [range start number],[range end number]
- *weighted* - [number of child rows]~[weight]^[number of child rows]~[weight]

**Example:**

*Creating a field called prod_id, referencing product table and the column product_id, with only one child row*

    prod_id#number#£product¤product_id¤simple¤1#<input arguments>

*Creating a field called cust_id, referencing customer table and the column customer_id, with between 2 and 7 child rows per parent rows*

    cust_id#number#£customer¤customer_id¤range¤2,7#<input arguments>

*Creating a field called card_id, referencing customer_cards table and the column ccard_id, with a weighted number of child rows. 10% chance for 2 rows, 30% chance for 3 rows and 60% chance for 4 rows*

    card_id#number#£customer_cards¤ccard_id¤weighted¤2~0.1^3~0.3^4~0.6#<input arguments>

###### Fixed value data generator
This is not really a generator. It is simply if you want a column with a fixed value in your generator, you can use the fixed value format. Simply start the generator field with the '~' character and everything after that character and until either the '#' or the '@' character is met, is set as the fixed value for that column.

**Example:**

*Setting the ename column to always have the value SCOTT*

    ename#varchar2(150)#~SCOTT

*Setting the column called prod_desc to always have the value 'A product description'*

    prod_desc#varchar2(4000)#~A product description

##### Input argument syntax
This optional field where you can specify if you want to add arguments to the data generator function. The format is just like Oracle input syntax. So either a comma separated list of arguments or named notation. So the same way you would call the function in either sqlplus or plsql.

The arguments themselves can also be references to other column values in the test data generator columns. You can reference other columns using two '%' on each side. So if you wanted one of the arguments for a data generator to be from another column called prod_id, you can reference it as %%prod_id%%.

Any string argument with quotes, has to have two quotes just as a quote would need when setting a string value in plsql.

**Example:**

*Create a column called words and specify standard input to the dbms_random.string function. It takes 2 arguments, type and length*

    words#varchar2(50)#dbms_random.string#''A'',15

*Create a column called short where we only want to specify the input value for the parameter called len to a function called my_pkg.my_func*

    short#varchar2(50)#my_pkg.my_func#len => 10

*Create a column called first_name, with a data generator to create a name that takes an input called p_gender. That input is defined as a reference to another column called gender in the same generator.*

    gender#varchar2(1)#~F@first_name#varchar2(50)#my_pkg.my_name_gen#%%gender%%

### Auto Input Reference
In cases where you specify data generator functions where the input argument has the same name as another columns data generator function, the generator code will automatically use the output of that function as the input to the next function.

So if you have one function called f_ordertype as the data generator for one column, and then you have a function called f_orderprice in another column and that function has an input parameter called f_ordertype. In that case the value from the first column will be used as the input to the second column.

### Building Generators
The way you build a generator is by using the procedure called testdata_ninja.generator_create. It has two input parameters:

- *generator_name* - The name of the generator. For versions older than 12.2 it is limited to a length of 26 characters.
- *generator_format* - This is the format of all your columns in the generator.

A simple demonstration code on how to use the procedure to build a generator could be:

    declare
      my_generator_format   varchar2(4000) := 'empid#number#^numiterate~1~1¤1@ename#varchar2(15)#dbms_random.string#''A'',15';
    begin
      testdata_ninja.generator_create('test_generator', my_generator_format);
    end;
    /

Once the procedure has been run successfully, the generator will be available as a package in the same schema. The name of the generator is always prefixed with 'TDG_'. So in the example above we would have a pacakge called 'TDG_TEST_GENERATOR'. Inside the package is a pipelined function named 'TEST_GENERATOR'. This pipelined function is the actual row generator.

### Using Generators

Once a generator is build you use it by selecting from the generator's pipelined function. So if we take the example from the previous section, we can use the 'TEST_GENERATOR' function like this:

    select * from table(tdg_test_generator.test_generator);

by default the number of rows generated will be 100. This can be changed in 2 different ways. One is by using the first input parameter which is the generator count. So to generate 5000 rows, you would run:

    select * from table(tdg_test_generator.test_generator(5000));

Another way to set the number of rows is to first change the package variable then any subsequent calls to the generator in that session will generate the set amount of rows:

    begin
      tdg_test_generator.g_default_generator_rows := 5000;
    end;
    /

Then any calls to the pipelined function afterwards will generate 5000 rows in the results, unless the number of rows are specified as the input.

## Full Generator Examples
For more examples on how to use this package you can take a look at the blog series I did on the package on my Codemonth blog:

- [Basic usage](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::12170:Creating-real-test-data---Fast-and-Efficiently)
- [Foreign key example](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::12570:Test-data-and-foreign-keys)
- [Using built-in incremental functions](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::12580:Generating-randomized-incremental-values-)
- [Using columns as references to input arguments](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::13376:Even-more-test-data-generated-using-the-testdata_ninja-plsql-package)
- [Generating physical tables or CSV output](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::13377:PLSQL-test-data-from-cursor-to-table-or-from-cursor-to-csv)
- [Recursive foreign key references](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::13378:Recursive-test-data-using-plsql-and-the-testdata_ninja-package)
- [Demo on auto input references](http://www.codemonth.dk/code_is_good/dev_qa_prod.assert?condition=codemonth::::13379:PLSQL-Test-data-generators-with-auto-back-reference-fields)
