create or replace package body testdata_ninja

as

  function people (
    generator_count         number default g_default_generator_rows
  )
  return person_tab
  pipelined

  as

    l_ret_var               person_rec;

    cursor generator is
      select --+ materialize
        rownum
      from
        dual
      connect by
        level <= generator_count;


  begin

    dbms_application_info.set_action('people');

    for x in generator loop
      l_ret_var.person_num_pk := x.rownum;
      l_ret_var.person_char_pk := sys_guid();
      l_ret_var.person_cdate := sysdate;
      l_ret_var.country_short := 'US';
      l_ret_var.gender := person_random.r_gender;
      l_ret_var.identification := person_random.r_identification;
      l_ret_var.first_name := person_random.r_firstname(l_ret_var.country_short, l_ret_var.gender);
      if core_random.r_bool then
        l_ret_var.middle_name := person_random.r_middlename(l_ret_var.country_short, l_ret_var.gender);
      end if;
      l_ret_var.last_name := person_random.r_lastname(l_ret_var.country_short, l_ret_var.gender);
      l_ret_var.birthdate := person_random.r_birthday;
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    dbms_application_info.set_action(null);

    return;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end people;

  function users (
    generator_count         number default g_default_generator_rows
  )
  return user_tab
  pipelined

  as

    l_ret_var               user_rec;

    cursor generator is
      select --+ materialize
        rownum
      from
        dual
      connect by
        level <= generator_count;

  begin

    dbms_application_info.set_action('users');

    for x in generator loop
      l_ret_var.user_num_pk := x.rownum;
      l_ret_var.user_char_pk := sys_guid();
      l_ret_var.user_cdate := sysdate;
      l_ret_var.username := person_random.r_name;
      l_ret_var.email := web_random.r_email;
      l_ret_var.address1 := location_random.r_address;
      l_ret_var.address2 := null;
      l_ret_var.zipcode := location_random.r_zipcode;
      l_ret_var.state := location_random.r_state;
      l_ret_var.creditcard := finance_random.r_creditcard;
      l_ret_var.creditcard_num := finance_random.r_creditcardnum(l_ret_var.creditcard);
      l_ret_var.creditcard_expiry := finance_random.r_expirydate;
      l_ret_var.password := core_random.r_hex(45);
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    dbms_application_info.set_action(null);

    return;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end users;

  function cdr (
    generator_count         number default g_default_generator_rows
  )
  return cdr_tab
  pipelined

  as

    l_ret_var               cdr_rec;

    cursor generator is
      select --+ materialize
        rownum
      from
        dual
      connect by
        level <= generator_count;

  begin

    dbms_application_info.set_action('cdr');

    for x in generator loop
      l_ret_var.cdr_num_pk := x.rownum;
      l_ret_var.cdr_char_pk := sys_guid();
      l_ret_var.cdr_cdate := sysdate;
      l_ret_var.orig_imsi := phone_random.r_imsi('AU');
      l_ret_var.orig_isdn := phone_random.r_phonenumber('AU',true);
      l_ret_var.orig_imei := phone_random.r_imei;
      l_ret_var.call_type := phone_random.r_call_type;
      l_ret_var.call_type_service := phone_random.r_call_type_service;
      l_ret_var.call_start_latitude := location_random.r_latitude;
      l_ret_var.call_start_longtitude := location_random.r_longtitude;
      l_ret_var.call_date := time_random.r_timestamp;
      l_ret_var.call_duration := core_random.r_natural(5,180);
      l_ret_var.dest_imsi := phone_random.r_imsi('AU');
      l_ret_var.dest_isdn := phone_random.r_phonenumber('AU',true);
      l_ret_var.dest_imei := phone_random.r_imei;
      l_ret_var.network_operator := phone_random.r_operator_code('AU');
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    dbms_application_info.set_action(null);

    return;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end cdr;

  function articles (
    generator_count         number default g_default_generator_rows
  )
  return news_article_tab
  pipelined

  as

    l_ret_var               news_article_rec;

    cursor generator is
      select --+ materialize
        rownum
      from
        dual
      connect by
        level <= generator_count;

  begin

    dbms_application_info.set_action('articles');

    for x in generator loop
      l_ret_var.news_article_num_pk := x.rownum;
      l_ret_var.news_article_char_pk := sys_guid();
      l_ret_var.news_article_cdate := sysdate;
      l_ret_var.author := person_random.r_name;
      l_ret_var.written := time_random.r_date;
      l_ret_var.headline := text_random.r_sentence(core_random.r_natural(5,15));
      l_ret_var.lead_paragraph := text_random.r_paragraph;
      l_ret_var.main_article := text_random.r_paragraph || ' ' || text_random.r_paragraph || ' ' || text_random.r_paragraph || ' ' || text_random.r_paragraph || ' ' || text_random.r_paragraph || ' ' || text_random.r_paragraph;
      l_ret_var.end_paragraph := text_random.r_paragraph;
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    dbms_application_info.set_action(null);

    return;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end articles;

begin

  dbms_application_info.set_client_info('testdata_ninja');
  dbms_session.set_identifier('testdata_ninja');

end testdata_ninja;
/
