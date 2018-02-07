create or replace package body testdata_data_infer

as

  procedure set_initial_col_assumptions (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

  begin

    dbms_application_info.set_action('set_initial_col_assumptions');

    -- Set initial assumptions of data.
    if metadata.table_base_stats.num_rows = metadata.table_columns(col_idx).column_base_stats.num_distinct then
      metadata.table_columns(col_idx).column_assumptions.col_is_unique := 1;
    else
      metadata.table_columns(col_idx).column_assumptions.col_is_unique := 0;
    end if;

    if metadata.table_columns(col_idx).column_base_data.low_value is null then
      metadata.table_columns(col_idx).column_assumptions.col_all_null := 1;
      metadata.table_columns(col_idx).column_assumptions.col_low_high_same := 1;
    else
      metadata.table_columns(col_idx).column_assumptions.col_all_null := 0;
      if metadata.table_columns(col_idx).column_base_data.low_value = metadata.table_columns(col_idx).column_base_data.high_value then
        metadata.table_columns(col_idx).column_assumptions.col_low_high_same := 1;
      else
        metadata.table_columns(col_idx).column_assumptions.col_low_high_same := 0;
      end if;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end set_initial_col_assumptions;

  procedure set_final_col_assumptions (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

  begin

    dbms_application_info.set_action('set_final_col_assumptions');

    -- Set the nullable value for generated columns.
    if metadata.table_columns(col_idx).column_base_data.nullable = 'Y' and metadata.table_columns(col_idx).inf_col_type = 'generated' then
      if metadata.table_columns(col_idx).column_base_stats.num_nulls > 0 then
        metadata.table_columns(col_idx).inf_col_generator_nullable := round(metadata.table_columns(col_idx).column_base_stats.num_nulls/(metadata.table_base_stats.num_rows/100),2);
      end if;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end set_final_col_assumptions;

  procedure infer_varchar_col (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

    l_low_val                 varchar2(4000) := null;
    l_high_val                varchar2(4000) := null;

  begin

    dbms_application_info.set_action('infer_varchar_col');

    if metadata.table_columns(col_idx).column_base_data.low_value is not null then
      l_low_val := utl_raw.cast_to_varchar2(metadata.table_columns(col_idx).column_base_data.low_value);
      l_high_val := utl_raw.cast_to_varchar2(metadata.table_columns(col_idx).column_base_data.high_value);
    end if;

    metadata.table_columns(col_idx).inf_col_domain := 'Text';
    metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';

    -- Check if we are dealing with a hit in data domain.
    for i in 1..testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type).count loop
      if util_random.ru_inlist(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_name_hit, metadata.table_columns(col_idx).column_name) then
        -- We hit a generated domain.
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator;
        metadata.table_columns(col_idx).inf_col_generator_args := replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val);
      end if;
    end loop;

    if metadata.table_columns(col_idx).inf_col_generator is null then
      -- If we have not yet infered a column generator (based on simple naming of columns)
      -- Let us see if we can infer from patterns in the data.
      -- First we check known patterns.
      testdata_data_pattern.find_known_pattern_in_col(metadata, col_idx);
    end if;

    if metadata.table_columns(col_idx).inf_col_generator is null then
      -- If we have not yet infered a column generator (based on simple naming of columns and known format strings)
      -- Let us see if we can guess from patterns in the data.
      testdata_data_pattern.guess_pattern_in_col(metadata, col_idx);
    end if;

    if metadata.table_columns(col_idx).inf_col_generator is null then
      -- We've reached the end without a hit in the infer. Let us run some other checks.
      if l_low_val = l_high_val then
        metadata.table_columns(col_idx).inf_col_type := 'fixed';
        if l_low_val = upper(l_low_val) then
          -- Value is fixed AND uppercase
          metadata.table_columns(col_idx).inf_fixed_value := upper(core_random.r_string(length(l_low_val), 'abcdefghijklmnopqrstuvwxy'));
        else
          metadata.table_columns(col_idx).inf_fixed_value := core_random.r_string(length(l_low_val), 'abcdefghijklmnopqrstuvwxy');
        end if;
      else
        -- We could not guess anything about this column. Set to default text string.
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := 'core_random.r_string';
        metadata.table_columns(col_idx).inf_col_generator_args := 'core_random.r_natural('|| nvl(length(l_low_val), 4) ||', '|| nvl(length(l_high_val), 10) ||') , ''abcdefghijklmnopqrstuvwxy''';
      end if;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end infer_varchar_col;

  procedure infer_number_col (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

    l_low_val                 number := null;
    l_high_val                number := null;

  begin

    dbms_application_info.set_action('infer_number_col');

    if metadata.table_columns(col_idx).column_base_data.low_value is not null then
      l_low_val := utl_raw.cast_to_number(metadata.table_columns(col_idx).column_base_data.low_value);
      l_high_val := utl_raw.cast_to_number(metadata.table_columns(col_idx).column_base_data.high_value);
    end if;

    -- Check if we are dealing with a hit in data domain.
    for i in 1..testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type).count loop
      if util_random.ru_inlist(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_name_hit, metadata.table_columns(col_idx).column_name) then
        -- We hit a generated domain.
        metadata.table_columns(col_idx).inf_col_domain := 'Number';
        metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator;
        metadata.table_columns(col_idx).inf_col_generator_args := replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val);
      end if;
    end loop;

    if metadata.table_columns(col_idx).inf_col_generator is null then
      -- Check for built-ins
      if metadata.table_columns(col_idx).column_assumptions.col_is_unique = 1 then
        -- This is a unqiue number, so make it a builtin type.
        metadata.table_columns(col_idx).inf_col_domain := 'Number';
        metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
        metadata.table_columns(col_idx).inf_col_type := 'builtin';
        metadata.table_columns(col_idx).inf_builtin_type := 'numiterate';
        metadata.table_columns(col_idx).inf_builtin_function := 'util_random.ru_number_increment';
        metadata.table_columns(col_idx).inf_builtin_startpoint := l_low_val; -- TODO Should be a "rescramble" so not the same as prod.
        metadata.table_columns(col_idx).inf_builtin_increment := '1¤1'; -- TODO Should do pattern and check the increment.
        metadata.table_columns(col_idx).inf_builtin_define_code := '
          l_bltin_' || metadata.table_columns(col_idx).column_name || ' number := ' || metadata.table_columns(col_idx).inf_builtin_startpoint || ';';
        metadata.table_columns(col_idx).inf_builtin_logic_code := '
          l_bltin_' || metadata.table_columns(col_idx).column_name || ' := ' || metadata.table_columns(col_idx).inf_builtin_function || '(l_bltin_' || metadata.table_columns(col_idx).column_name || ', ' || util_random.ru_extract(metadata.table_columns(col_idx).inf_builtin_increment, 1, '¤') || ', ' || util_random.ru_extract(metadata.table_columns(col_idx).inf_builtin_increment, 2, '¤') || ');';
      else
        -- We've reached the end without a hit in the infer. Set to default.
        metadata.table_columns(col_idx).inf_col_domain := 'Number';
        metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := 'core_random.r_integer';
        metadata.table_columns(col_idx).inf_col_generator_args := nvl(l_low_val, 4) || ',' || nvl(l_high_val, 10);
      end if;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end infer_number_col;

  procedure infer_date_col (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

    l_low_val                 date := null;
    l_high_val                date := null;

  begin

    dbms_application_info.set_action('infer_date_col');

    if metadata.table_columns(col_idx).column_base_data.low_value is not null then
      l_low_val := to_date(rtrim(to_char(100*(to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,1,2),'XX')-100)
                    + (to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,3,2),'XX')-100),'fm0000')||'-'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,5,2),'XX'),'fm00')||'-'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,7,2),'XX'),'fm00')||' '||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,9,2),'XX')-1,'fm00')||':'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,11,2),'XX')-1,'fm00')||':'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.low_value,13,2),'XX')-1,'fm00')), 'YYYY-MM-DD HH24:MI:SS');
      l_high_val := to_date(rtrim(to_char(100*(to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,1,2),'XX')-100)
                    + (to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,3,2),'XX')-100),'fm0000')||'-'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,5,2),'XX'),'fm00')||'-'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,7,2),'XX'),'fm00')||' '||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,9,2),'XX')-1,'fm00')||':'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,11,2),'XX')-1,'fm00')||':'||
                    to_char(to_number(substr(metadata.table_columns(col_idx).column_base_data.high_value,13,2),'XX')-1,'fm00')), 'YYYY-MM-DD HH24:MI:SS');
    end if;

    -- Check if we are dealing with a hit in data domain.
    for i in 1..testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type).count loop
      if util_random.ru_inlist(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_name_hit, metadata.table_columns(col_idx).column_name) then
        -- We hit a generated domain.
        metadata.table_columns(col_idx).inf_col_domain := 'Date';
        metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator;
        metadata.table_columns(col_idx).inf_col_generator_args := replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val);
      end if;
    end loop;

    if metadata.table_columns(col_idx).inf_col_generator is null then
      -- We've reached the end without a hit in the infer. Set to default.
      metadata.table_columns(col_idx).inf_col_domain := 'Date';
      metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
      metadata.table_columns(col_idx).inf_col_type := 'generated';
      metadata.table_columns(col_idx).inf_col_generator := 'time_random.r_date';
      metadata.table_columns(col_idx).inf_col_generator_args := null;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end infer_date_col;

  procedure infer_table_domain (
    metadata             in out nocopy        testdata_ninja.main_tab_meta
  )

  as

    l_table_domain_idx        varchar2(250);

  begin

    dbms_application_info.set_action('infer_table_domain');

    l_table_domain_idx := testdata_generator_domains.g_table_domains.first;
    while l_table_domain_idx is not null loop
      if instr(metadata.table_name, testdata_generator_domains.g_table_domains(l_table_domain_idx)) > 0 then
        metadata.inf_table_domain := l_table_domain_idx;
        exit;
      end if;
      l_table_domain_idx := testdata_generator_domains.g_table_domains.next(l_table_domain_idx);
    end loop;

    if metadata.inf_table_domain is null then
      metadata.inf_table_domain := null;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end infer_table_domain;

  procedure infer_generators (
    metadata             in out nocopy        testdata_ninja.main_tab_meta
  )

  as

  begin

    dbms_application_info.set_action('infer_generators');

    -- First build some assumptions on the table itself.
    infer_table_domain(metadata);

    -- Then build assumptions on the columns and set generators.
    for c in 1..metadata.table_columns.count loop
      -- First we set some initial assumptions on the column.
      set_initial_col_assumptions(metadata, c);
      -- set the generator based on data type.
      if metadata.table_columns(c).column_type = 'VARCHAR2' then
        infer_varchar_col(metadata, c);
      elsif metadata.table_columns(c).column_type = 'NUMBER' then
        infer_number_col(metadata, c);
      elsif metadata.table_columns(c).column_type = 'DATE' then
        infer_date_col(metadata, c);
      end if;
      -- Set the final assumptions and generic settings.
      set_final_col_assumptions(metadata, c);
    end loop;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end infer_generators;

begin

  dbms_application_info.set_client_info('testdata_data_infer');
  dbms_session.set_identifier('testdata_data_infer');

end testdata_data_infer;
/
