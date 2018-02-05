create or replace package body testdata_generator_domains

as

begin

  -- TABLE DOMAINS
  g_table_domains('Company employee') := 'EMP,EMPS,EMPLOYEES,STAFF,EMPLOYEE';
  g_table_domains('Company location') := 'DEP,DEPT,DEPARTMENT,DEPARTMENTS,LOCATION,LOCATIONS';
  g_table_domains('Commerce order') := 'ORDERS,ORDER_ITEMS,ORDER_DETAIL';

  -- COLUMN DOMAINS
  -- varchar2
  g_column_domains('VARCHAR2') := col_domain_tab();
  g_column_domains('VARCHAR2').extend(6);
  g_column_domains('VARCHAR2')(1).col_name_hit := 'FNAME,FIRSTNAME,FIRST_NAME';
  g_column_domains('VARCHAR2')(1).col_generator := 'person_random.r_firstname';
  g_column_domains('VARCHAR2')(1).col_generator_args := null;
  g_column_domains('VARCHAR2')(2).col_name_hit := 'LNAME,LASTNAME,LAST_NAME,ENAME';
  g_column_domains('VARCHAR2')(2).col_generator := 'person_random.r_lastname';
  g_column_domains('VARCHAR2')(2).col_generator_args := null;
  g_column_domains('VARCHAR2')(3).col_name_hit := 'FULLNAME,FULL_NAME';
  g_column_domains('VARCHAR2')(3).col_generator := 'person_random.r_name';
  g_column_domains('VARCHAR2')(3).col_generator_args := null;
  g_column_domains('VARCHAR2')(4).col_name_hit := 'CNTRY,COUNTRY,CTRY';
  g_column_domains('VARCHAR2')(4).col_generator := 'location_random.r_country';
  g_column_domains('VARCHAR2')(4).col_generator_args := 'r_shortform => true';
  g_column_domains('VARCHAR2')(5).col_name_hit := 'JOB,TITLE,JOBTITLE,JOB_TITLE';
  g_column_domains('VARCHAR2')(5).col_generator := 'person_random.r_jobtitle';
  g_column_domains('VARCHAR2')(5).col_generator_args := null;
  g_column_domains('VARCHAR2')(6).col_name_hit := 'LOCATION,LOC,CITY,TOWN';
  g_column_domains('VARCHAR2')(6).col_generator := 'location_random.r_city';
  g_column_domains('VARCHAR2')(6).col_generator_args := null;
  -- number
  g_column_domains('NUMBER') := col_domain_tab();
  g_column_domains('NUMBER').extend(2);
  g_column_domains('NUMBER')(1).col_name_hit := 'SALARY,SAL,BONUS,PAY,INCOME';
  g_column_domains('NUMBER')(1).col_generator := 'person_random.r_salary';
  g_column_domains('NUMBER')(1).col_generator_args := 'r_min => [low], r_max => [high]';
  g_column_domains('NUMBER')(2).col_name_hit := 'PRICE,ORDER,PAYMENT,COST';
  g_column_domains('NUMBER')(2).col_generator := 'finance_random.r_amount';
  g_column_domains('NUMBER')(2).col_generator_args := 'r_min => [low], r_max=> [high]';
  -- date
  g_column_domains('DATE') := col_domain_tab();
  g_column_domains('DATE').extend(1);
  g_column_domains('DATE')(1).col_name_hit := 'HIREDATE,BIRTHDAY,BIRTH_DATE,BIRTH_DAY,BIRTHDATE,DAY,HIRE_DATE,HDATE';
  g_column_domains('DATE')(1).col_generator := 'time_random.r_datebetween';
  g_column_domains('DATE')(1).col_generator_args := 'r_date_from => to_date(''[low]'',''DD-MON-YYYY HH24:MI:SS''), r_date_to => to_date(''[high]'',''DD-MON-YYYY HH24:MI:SS'')';

  dbms_application_info.set_client_info('testdata_generator_domains');
  dbms_session.set_identifier('testdata_generator_domains');

end testdata_generator_domains;
/
