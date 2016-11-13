create or replace package body testdata_ninja

as

  procedure generator_create (
    generator_name              in        varchar2
    , generator_format          in        varchar2
  )

  as

    l_generator_pkg_head        varchar2(32000);
    l_generator_pkg_body        varchar2(32000);
    l_format_elements           number;
    l_format_element            varchar2(500);

  begin

    dbms_application_info.set_action('generator_create');

    l_format_elements := regexp_count(generator_format, '@') + 1;

    l_generator_pkg_head := 'create or replace package tdg_'|| generator_name ||'
      as
        g_default_generator_rows      number := 10;

        type '|| generator_name ||'_rec is record (
        ';

        for i in 1..l_format_elements loop
          l_format_element := util_random.ru_extract(generator_format, i, '@');
          if i = 1 then
            l_generator_pkg_head := l_generator_pkg_head || util_random.ru_extract(l_format_element, 1, '#') || ' ' || util_random.ru_extract(l_format_element, 2, '#');
          else
            l_generator_pkg_head := l_generator_pkg_head || ', ' || util_random.ru_extract(l_format_element, 1, '#') || ' ' || util_random.ru_extract(l_format_element, 2, '#');
          end if;
        end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
        );
        type '|| generator_name ||'_tab is table of '|| generator_name ||'_rec;

        function '|| generator_name ||' (
          generator_count         number default g_default_generator_rows
        )
        return '|| generator_name ||'_tab
        pipelined;

      end tdg_'|| generator_name ||';';

      dbms_output.put_line(l_generator_pkg_head);

      execute immediate l_generator_pkg_head;

    l_generator_pkg_body := 'create or replace package body tdg_'|| generator_name ||'
      as

        function '|| generator_name ||' (
          generator_count         number default g_default_generator_rows
        )
        return '|| generator_name ||'_tab
        pipelined

        as

          l_ret_var       '|| generator_name ||'_rec;

          cursor generator is
            select --+ materialize
              rownum
            from
              dual
            connect by
              level <= generator_count;

        begin

          for x in generator loop
      ';

      for i in 1..l_format_elements loop
        l_format_element := util_random.ru_extract(generator_format, i, '@');
        l_generator_pkg_body := l_generator_pkg_body || ' l_ret_var.' || util_random.ru_extract(l_format_element, 1, '#') || ' := ' || util_random.ru_extract(l_format_element, 3, '#') || ';';
      end loop;

      l_generator_pkg_body := l_generator_pkg_body || '
            pipe row(l_ret_var);
            l_ret_var := null;
          end loop;

          return;

          exception
            when others then
              null;
        end;
      end tdg_'|| generator_name ||';';

    execute immediate l_generator_pkg_body;


    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end generator_create;

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

  function population (
    country                 varchar2 default null
    , generator_count       number default g_default_population_size
  )
  return person_tab
  pipelined

  as

    -- Base variables.
    l_ret_var               person_rec;
    l_country               varchar2(10) := country;
    l_population_size       number;

    -- Demographics variables.
    l_people_0_14           number;
    l_people_0_14_m         number;
    l_people_15_64          number;
    l_people_15_64_m        number;
    l_people_65_            number;
    l_people_65_m           number;

    -- Temporary working variables.
    l_age                   number;
    l_gender                varchar2(10);

    cursor generator(n number) is
      select --+ materialize
        rownum
      from
        dual
      connect by
        level <= n;

  begin

    dbms_application_info.set_action('population');

    if l_country is null then
      l_country := 'US';
    -- elsif not demograhics_data.c_d_arr.exists(l_country) then
    --  l_country := 'US';
    end if;

    -- Calculate proportions of people.
    l_population_size := round(demograhics_data.c_d_arr(l_country).population * generator_count);
    l_people_0_14 := round((l_population_size/100) * demograhics_data.c_d_arr(l_country).p_0_14);
    l_people_0_14_m := (l_people_0_14/2) + (l_people_0_14 * (demograhics_data.c_d_arr(l_country).p_0_14_mf - 1));
    l_people_15_64 := round((l_population_size/100) * demograhics_data.c_d_arr(l_country).p_15_64);
    l_people_15_64_m := (l_people_15_64/2) + (l_people_15_64 * (demograhics_data.c_d_arr(l_country).p_15_64_mf - 1));
    l_people_65_ := round((l_population_size/100) * demograhics_data.c_d_arr(l_country).p_65_);
    l_people_65_m := (l_people_65_/2) + (l_people_65_ * (demograhics_data.c_d_arr(l_country).p_65_mf - 1));

    -- Generate children
    for x in generator(l_people_0_14) loop
      if x.rownum <= l_people_0_14_m then
        l_gender := 'male';
      else
        l_gender := 'female';
      end if;
      l_ret_var.person_num_pk := x.rownum;
      l_ret_var.person_char_pk := sys_guid();
      l_ret_var.person_cdate := sysdate;
      l_ret_var.country_short := l_country;
      l_ret_var.gender := l_gender;
      l_ret_var.identification := person_random.r_identification(l_country);
      l_ret_var.first_name := person_random.r_firstname(l_country, l_gender);
      if core_random.r_bool then
        l_ret_var.middle_name := person_random.r_middlename(l_country, l_gender);
      end if;
      l_ret_var.last_name := person_random.r_lastname(l_country, l_gender);
      l_ret_var.birthdate := person_random.r_birthday(null, false, 0, 14);
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    -- Generate adult
    for x in generator(l_people_15_64) loop
      if x.rownum <= l_people_15_64_m then
        l_gender := 'male';
      else
        l_gender := 'female';
      end if;
      l_ret_var.person_num_pk := x.rownum;
      l_ret_var.person_char_pk := sys_guid();
      l_ret_var.person_cdate := sysdate;
      l_ret_var.country_short := l_country;
      l_ret_var.gender := l_gender;
      l_ret_var.identification := person_random.r_identification(l_country);
      l_ret_var.first_name := person_random.r_firstname(l_country, l_gender);
      if core_random.r_bool then
        l_ret_var.middle_name := person_random.r_middlename(l_country, l_gender);
      end if;
      l_ret_var.last_name := person_random.r_lastname(l_country, l_gender);
      l_ret_var.birthdate := person_random.r_birthday(null, false, 15, 64);
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    -- Generate senior.
    for x in generator(l_people_65_) loop
      if x.rownum <= l_people_65_m then
        l_gender := 'male';
      else
        l_gender := 'female';
      end if;
      l_ret_var.person_num_pk := x.rownum;
      l_ret_var.person_char_pk := sys_guid();
      l_ret_var.person_cdate := sysdate;
      l_ret_var.country_short := l_country;
      l_ret_var.gender := l_gender;
      l_ret_var.identification := person_random.r_identification(l_country);
      l_ret_var.first_name := person_random.r_firstname(l_country, l_gender);
      if core_random.r_bool then
        l_ret_var.middle_name := person_random.r_middlename(l_country, l_gender);
      end if;
      l_ret_var.last_name := person_random.r_lastname(l_country, l_gender);
      l_ret_var.birthdate := person_random.r_birthday(null, false, 65, 99);
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    dbms_application_info.set_action(null);

    return;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end population;

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

  function creditcardtransactions (
    generator_count         number default g_default_generator_rows
  )
  return cc_transaction_tab
  pipelined

  as

    l_ret_var               cc_transaction_rec;

    cursor generator is
      select --+ materialize
        rownum
      from
        dual
      connect by
        level <= generator_count;

  begin

    dbms_application_info.set_action('creditcardtransactions');

    for x in generator loop
      l_ret_var.cc_transaction_num_pk := x.rownum;
      l_ret_var.cc_transaction_char_pk := sys_guid();
      l_ret_var.cc_transaction_cdate := sysdate;
      l_ret_var.creditcard_num := finance_random.r_creditcardnum;
      l_ret_var.transaction_date := time_random.r_timebetween(systimestamp - interval '30' day);
      l_ret_var.transaction_type := finance_random.r_creditcard_tx_type;
      l_ret_var.transaction_amount := core_random.r_float(2, 5, 2500, 15, 175, 80);
      pipe row(l_ret_var);

      l_ret_var := null;
    end loop;

    dbms_application_info.set_action(null);

    return;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end creditcardtransactions;

begin

  dbms_application_info.set_client_info('testdata_ninja');
  dbms_session.set_identifier('testdata_ninja');

end testdata_ninja;
/
