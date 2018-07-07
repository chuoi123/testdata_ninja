create or replace package body testdata_data_infer

as

  function calculate_infer_data_sample (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
    , tab_name            in                    varchar2 default null
  )
  return number

  as

    l_tab_approx_rcount     number;
    l_sample_count          number := 10;

  begin
    
    -- First we check approx row count in parent table.
    if tab_name is not null then
      select num_rows
      into l_tab_approx_rcount
      from user_tab_statistics
      where upper(table_name) = upper(tab_name);
    else
      select num_rows
      into l_tab_approx_rcount
      from user_tab_statistics
      where upper(table_name) = upper(metadata.table_name);
    end if;

    if l_tab_approx_rcount is not null and l_tab_approx_rcount < 1000 then
      l_sample_count := 99.99;
    else
      l_sample_count := round(1000/(l_tab_approx_rcount/100),2);
    end if;

    return l_sample_count;

  end calculate_infer_data_sample;

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

    -- Check if we are dealing with a hit in data domain directly.
    for i in 1..testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type).count loop
      if util_random.ru_inlist(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_name_hit, metadata.table_columns(col_idx).column_name) then
        -- We hit a generated domain directly.
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator;
        if testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_args_condition = 1 then
          execute immediate replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val)
          into metadata.table_columns(col_idx).inf_col_generator_args;
        else
          metadata.table_columns(col_idx).inf_col_generator_args := replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val);
        end if;
      end if;
    end loop;

    -- We basically repeat same loop as above if generator is null
    -- but this time allowing for partial matching.
    -- TODO: In future should make this less repetative
    if metadata.table_columns(col_idx).inf_col_generator is null then
      for i in 1..testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type).count loop
        if util_random.ru_inlist(ru_elements => testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_name_hit, ru_value => metadata.table_columns(col_idx).column_name, ru_partial_hit => true) then
          -- We hit a generated with partial match.
          metadata.table_columns(col_idx).inf_col_type := 'generated';
          metadata.table_columns(col_idx).inf_col_generator := testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator;
          if testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_args_condition = 1 then
            execute immediate replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val)
            into metadata.table_columns(col_idx).inf_col_generator_args;
          else
            metadata.table_columns(col_idx).inf_col_generator_args := replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', l_low_val), '[high]', l_high_val);
          end if;
        end if;
      end loop;
    end if;

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

    -- Now that we have the generator defined
    -- We need to check if we need to track uniqueness.
    -- If so, we need to create the define and logic code.
    if metadata.table_columns(col_idx).column_is_unique > 0 and metadata.table_columns(col_idx).inf_col_type = 'generated' then
      -- Define code
      metadata.table_columns(col_idx).inf_unique_define_code := '
        type t_' || metadata.table_columns(col_idx).column_name || '_u_tab is table of number(1) index by varchar2(4000);
        l_' || metadata.table_columns(col_idx).column_name || '_u t_' || metadata.table_columns(col_idx).column_name || '_u_tab;';
      -- Logic code
      metadata.table_columns(col_idx).inf_unique_logic_code := '
        if maintain_uniqueness then
          ##col_set_code##
          while l_' || metadata.table_columns(col_idx).column_name || '_u.exists(l_ret_var.' || metadata.table_columns(col_idx).column_name || ') loop
            ##col_set_code##
          end loop;
          l_' || metadata.table_columns(col_idx).column_name || '_u(l_ret_var.' || metadata.table_columns(col_idx).column_name || ') := 1;
        else
          ##col_set_code##
        end if;';
    end if;

    dbms_application_info.set_action(null);

  end infer_varchar_col;

  procedure infer_number_col (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

    l_low_val                 number := null;
    l_high_val                number := null;
    l_sample_count            number := calculate_infer_data_sample(metadata, col_idx);
    l_sample_sql              varchar2(4000) := 'select
                                    max(lag_sample_col_diff)
                                    , min(lag_sample_col_diff)
                                    , round(avg(lag_sample_col_diff))
                                from (
                                  select
                                      '|| metadata.table_columns(col_idx).column_name ||'-lag_sample_col lag_sample_col_diff
                                  from (
                                    select 
                                        '|| metadata.table_columns(col_idx).column_name ||'
                                        , lag('|| metadata.table_columns(col_idx).column_name ||', 1, null) over (order by '|| metadata.table_columns(col_idx).column_name ||') lag_sample_col
                                    from 
                                      '|| metadata.table_name ||' sample ('|| l_sample_count ||')
                                  )
                                  where 
                                    '|| metadata.table_columns(col_idx).column_name ||'-lag_sample_col > 0
                                )';
    l_sample_max_diff         number;
    l_sample_min_diff         number;
    l_sample_avg_diff         number;

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
        metadata.table_columns(col_idx).inf_builtin_startpoint := util_random.ru_numerify(replace(rpad(' ', length(l_low_val), '#'), ' ', '#'));
        -- Sample increment pattern, and try to construct similar pattern
        execute immediate l_sample_sql into l_sample_max_diff, l_sample_min_diff, l_sample_avg_diff;
        if l_sample_max_diff = l_sample_min_diff and l_sample_min_diff = l_sample_avg_diff then
          metadata.table_columns(col_idx).inf_builtin_increment := l_sample_min_diff || '¤' || l_sample_max_diff;
        else
          metadata.table_columns(col_idx).inf_builtin_increment := core_random.r_natural(l_sample_min_diff, l_sample_avg_diff) || '¤' || core_random.r_natural(l_sample_avg_diff, l_sample_max_diff);
        end if;
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
    l_sample_count            number := calculate_infer_data_sample(metadata, col_idx);
    l_always_increment        boolean := true;
    l_is_incrementing         number := 0;
    l_always_incr_sample_stmt varchar2(4000) := 'select
          case
              when ldat < '|| metadata.table_columns(col_idx).column_name ||' then 1
              else 0
          end iscon
      from (
      select 
          '|| metadata.table_columns(col_idx).column_name ||'
          , lead('|| metadata.table_columns(col_idx).column_name ||', 1, null) over (order by rowid) ldat
      from '|| metadata.table_name ||' sample ('|| l_sample_count ||')
      order by rowid)';
    l_date_incr_data_stmt     varchar2(4000) := 'select distinct
          rincr_type
          , count(rincr) over (partition by rincr_type order by rincr_type) cnt_b_t
          , avg(rincr) over (partition by rincr_type order by rincr_type) avg_b_t
          , min(rincr) over (partition by rincr_type order by rincr_type) min_b_t
          , max(rincr) over (partition by rincr_type order by rincr_type) max_b_t
      from (
      select
          case
              when round((ldat-'|| metadata.table_columns(col_idx).column_name ||')*86400) <= 60 then ''seconds''
              when round((ldat-'|| metadata.table_columns(col_idx).column_name ||')*86400) <= 3600 then ''minutes''
              when round((ldat-'|| metadata.table_columns(col_idx).column_name ||')*86400) <= 86400 then ''hours''
              else ''days''
          end rincr_type
          , round((ldat-'|| metadata.table_columns(col_idx).column_name ||')*86400) rincr
      from (
        select 
            '|| metadata.table_columns(col_idx).column_name ||'
            , lead('|| metadata.table_columns(col_idx).column_name ||', 1, null) over (order by rowid) ldat
        from '|| metadata.table_name ||' sample ('|| l_sample_count ||')
        order by rowid
      )
      where ldat is not null
      )';
    type l_incr_data_rec is record (
      incr_type               varchar2(4000)
      , incr_type_count       number
      , incr_type_avg         number
      , incr_type_min         number
      , incr_type_max         number
    );
    l_incr_data               l_incr_data_rec;
    l_incr_high_count         number := 0;
    l_incr_low_count          number := 0;
    l_incr_avg_count          number := 0;
    l_incr_most_count         number := 0;
    l_incr_total_count        number := 0;
    l_always_incr_ref_cursor  sys_refcursor;

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
        metadata.table_columns(col_idx).inf_col_generator_args := replace(replace(testdata_generator_domains.g_column_domains(metadata.table_columns(col_idx).column_type)(i).col_generator_args, '[low]', to_char(l_low_val, 'DD-MON-YYYY HH24:MI:SS')), '[high]', to_char(l_high_val, 'DD-MON-YYYY HH24:MI:SS'));
      end if;
    end loop;

    if metadata.table_columns(col_idx).inf_col_generator is null then
      if metadata.table_columns(col_idx).column_assumptions.col_is_unique = 1 then
        -- If all the rows are unique, we need to figure out if we are incrementing (always newer)
        -- or if it can be old/new out of order of the insert. Assume rowid as the order col.
        open l_always_incr_ref_cursor for l_always_incr_sample_stmt;
        loop
          fetch l_always_incr_ref_cursor into l_is_incrementing;
          exit when l_always_incr_ref_cursor%notfound;
          if l_is_incrementing = 1 then
            -- Not always incrementing. Set to false and exit.
            l_always_increment := false;
            exit;
          end if;
        end loop;
        close l_always_incr_ref_cursor;
        if l_always_increment then
          -- Set data for the date incrementer
          metadata.table_columns(col_idx).inf_col_domain := 'Date';
          metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
          metadata.table_columns(col_idx).inf_col_type := 'builtin';
          metadata.table_columns(col_idx).inf_builtin_type := 'datiterate';
          metadata.table_columns(col_idx).inf_builtin_function := 'util_random.ru_date_increment';
          metadata.table_columns(col_idx).inf_builtin_startpoint := to_char(l_low_val, 'DDMMYYYY-HH24:MI:SS');
          -- Now we find out what the increment is like.
          open l_always_incr_ref_cursor for l_date_incr_data_stmt;
          loop
            fetch l_always_incr_ref_cursor into l_incr_data;
            exit when l_always_incr_ref_cursor%notfound; 
            l_incr_total_count := l_incr_total_count + l_incr_data.incr_type_count;
            if l_incr_data.incr_type_count > l_incr_most_count then
              l_incr_most_count := l_incr_data.incr_type_count;
              l_incr_high_count := l_incr_data.incr_type_max;
              l_incr_low_count := l_incr_data.incr_type_min;
              l_incr_avg_count := l_incr_data.incr_type_avg;
            end if;          
          end loop;
          metadata.table_columns(col_idx).inf_builtin_increment := 'seconds¤'|| l_incr_low_count ||'¤'|| l_incr_high_count ||'';
          metadata.table_columns(col_idx).inf_builtin_define_code := '
            l_bltin_' || metadata.table_columns(col_idx).column_name || ' date := to_date(''' || metadata.table_columns(col_idx).inf_builtin_startpoint || ''', ''DDMMYYYY-HH24:MI:SS'');';
          metadata.table_columns(col_idx).inf_builtin_logic_code := '
            l_bltin_' || metadata.table_columns(col_idx).column_name || ' := ' || metadata.table_columns(col_idx).inf_builtin_function || '(l_bltin_' || metadata.table_columns(col_idx).column_name || ', ''' || util_random.ru_extract(metadata.table_columns(col_idx).inf_builtin_increment, 1, '¤') || ''', ' || util_random.ru_extract(metadata.table_columns(col_idx).inf_builtin_increment, 2, '¤') || ', ' || util_random.ru_extract(metadata.table_columns(col_idx).inf_builtin_increment, 3, '¤') || ');';
        else
          -- TODO here we should find distribution of date (year, month, day)
          -- to build realistic dates
          metadata.table_columns(col_idx).inf_col_domain := 'Date';
          metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
          metadata.table_columns(col_idx).inf_col_type := 'generated';
          metadata.table_columns(col_idx).inf_col_generator := 'time_random.r_datebetween';
          metadata.table_columns(col_idx).inf_col_generator_args := replace(replace('r_date_from => to_date(''[low]'',''DD-MON-YYYY HH24:MI:SS''), r_date_to => to_date(''[high]'',''DD-MON-YYYY HH24:MI:SS'')', '[low]', to_char(l_low_val, 'DD-MON-YYYY HH24:MI:SS')), '[high]', to_char(l_high_val, 'DD-MON-YYYY HH24:MI:SS'));
        end if;
      else
        -- We've reached the end without a hit in the infer. Set to default.
        metadata.table_columns(col_idx).inf_col_domain := 'Date';
        metadata.table_columns(col_idx).inf_col_change_pattern := 'Always';
        metadata.table_columns(col_idx).inf_col_type := 'generated';
        metadata.table_columns(col_idx).inf_col_generator := 'time_random.r_datebetween';
        metadata.table_columns(col_idx).inf_col_generator_args := replace(replace('r_date_from => to_date(''[low]'',''DD-MON-YYYY HH24:MI:SS''), r_date_to => to_date(''[high]'',''DD-MON-YYYY HH24:MI:SS'')', '[low]', to_char(l_low_val, 'DD-MON-YYYY HH24:MI:SS')), '[high]', to_char(l_high_val, 'DD-MON-YYYY HH24:MI:SS'));
      end if;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end infer_date_col;

  procedure infer_foreign_key_col (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

    l_parent_approx_rcount    number;
    l_do_fts_check            boolean := false;
    l_sample_count            number := 1;

    type l_sample_rec is record (
      ref_val_dis             number
      , ref_val_count         number
      , ref_lowest_count      number
      , ref_highest_count     number
    );
    type l_sample_tab is table of l_sample_rec;
    l_sample_val              l_sample_tab := l_sample_tab();

    type histogram_rec is record (
      val_begin               number
      , val_end               number
      , occurrences           number
      , weight                number
    );
    type ref_dist_hist_tab is table of histogram_rec;
    ref_histogram             ref_dist_hist_tab := ref_dist_hist_tab();
    l_bucket_count            number := 10;
    l_bucket_size             number;

    l_sample_data_cursor      sys_refcursor;

  begin

    -- First we check approx row count in parent table.
    select num_rows
    into l_parent_approx_rcount
    from user_tab_statistics
    where upper(table_name) = upper(metadata.table_columns(col_idx).column_def_ref_tab);

    if l_parent_approx_rcount is not null and l_parent_approx_rcount < 1000 then
      -- We can do a full check on all rows
      l_do_fts_check := true;
      l_sample_count := 99.99;
    else
      l_sample_count := round(1000/(l_parent_approx_rcount/100),2);
    end if;

    -- Let us check the distribution
    open l_sample_data_cursor for 'select
        ' || metadata.table_columns(col_idx).column_def_ref_col || '
        , fcnt
        , first_value(fcnt) ignore nulls over (order by fcnt) low_cnt
        , last_value(fcnt) ignore nulls over (order by fcnt rows between
           unbounded preceding and unbounded following) high_cnt
      from (
        select
          ora_hash(a.' || metadata.table_columns(col_idx).column_def_ref_col || ') ' || metadata.table_columns(col_idx).column_def_ref_col || '
          , count(b.' || metadata.table_columns(col_idx).column_name || ') fcnt
        from ' || metadata.table_columns(col_idx).column_def_ref_tab || ' a
          , ' || metadata.table_name || ' b
        where
          a.' || metadata.table_columns(col_idx).column_def_ref_col || ' = b.' || metadata.table_columns(col_idx).column_name || '
        and
          a.' || metadata.table_columns(col_idx).column_def_ref_col || ' in (
            select 
              ' || metadata.table_columns(col_idx).column_def_ref_col || '
            from
              ' || metadata.table_columns(col_idx).column_def_ref_tab || ' sample(' || l_sample_count || ')
          )
        group by
          a.' || metadata.table_columns(col_idx).column_def_ref_col || '
      )';
    
    fetch l_sample_data_cursor bulk collect into l_sample_val;

    if (l_sample_val(1).ref_highest_count - l_sample_val(1).ref_lowest_count) <= l_sample_val(1).ref_lowest_count then
      -- Distribution difference of child records are minimal. Just go range between low and high.
      metadata.table_columns(col_idx).inf_ref_type := 'range';
      metadata.table_columns(col_idx).inf_ref_distr_start := l_sample_val(1).ref_lowest_count;
      metadata.table_columns(col_idx).inf_ref_distr_end := l_sample_val(1).ref_highest_count;
    else
      -- We have to do a weighted distribution. So lets bucket this up in a histogram and give it weights.
      -- Yeah yeah I know, not optimal but at least it is a start :)
      if l_sample_val(1).ref_highest_count - l_sample_val(1).ref_lowest_count < 10 then
        l_bucket_count := 2;
      elsif l_sample_val(1).ref_highest_count < 20 then
        l_bucket_count := 4;
      end if;
      l_bucket_size := round(l_sample_val(1).ref_highest_count/l_bucket_count);
      -- Create buckets first.
      for i in 1..l_bucket_count loop
        ref_histogram.extend(1);
        if i = 1 then
          ref_histogram(i).val_begin := 1;
          ref_histogram(i).val_end := l_bucket_size;
        elsif i = l_bucket_count then
          ref_histogram(i).val_begin := ref_histogram(i-1).val_end + 1;
          ref_histogram(i).val_end := l_sample_val(1).ref_highest_count;
        else
          ref_histogram(i).val_begin := ref_histogram(i-1).val_end + 1;
          ref_histogram(i).val_end := ref_histogram(i).val_begin + l_bucket_size;
        end if;
        ref_histogram(i).occurrences := 0;
        ref_histogram(i).weight := 0;
      end loop;
      -- Building the histogram with weights as well.
      for i in 1..l_sample_val.count loop
        for y in 1..ref_histogram.count loop
          if l_sample_val(i).ref_val_count between ref_histogram(y).val_begin and ref_histogram(y).val_end then
            ref_histogram(y).occurrences := ref_histogram(y).occurrences + 1;
            ref_histogram(y).weight := round(((ref_histogram(y).occurrences/l_sample_val.count*100)));
            exit;
          end if;
        end loop;
      end loop;
      -- Finally we can build the weighted string for testdata_ninja
      metadata.table_columns(col_idx).inf_ref_type := 'weighted';
      for i in 1..ref_histogram.count loop
        if ref_histogram(i).weight > 0 then
          metadata.table_columns(col_idx).inf_ref_distr_start := metadata.table_columns(col_idx).inf_ref_distr_start || ',' || ref_histogram(i).occurrences || '[' || ref_histogram(i).weight || ']';
        end if;
      end loop;
      metadata.table_columns(col_idx).inf_ref_distr_start := substr(metadata.table_columns(col_idx).inf_ref_distr_start, 2);
    end if;

    close l_sample_data_cursor;

    -- Now we have the referential distribution. We have already infered a generator
    -- so we need to build some special logic for this one. Since we are basing this
    -- on an existing table, we need to allow for the fact that the parent table
    -- does not exist, so the code need to assert that and if not, then generate
    -- values instead of using an existing table.
    metadata.table_columns(col_idx).inf_col_type := 'reference field';

    -- When we build the logic for the code to handle a foreign key,
    -- we include the option to ignore relationship and just generate values
    -- from the initial inferred generator.
    -- TODO: REMOVE this code from here. Does not really belong here.

    -- Variable and cursor definitions for ref code.
    metadata.table_columns(col_idx).inf_ref_define_code := '
      type t_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_c_tab is table of number index by varchar2(4000);
      l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list t_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_c_tab;
      l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx varchar2(4000);';

    if metadata.table_columns(col_idx).inf_ref_type = 'simple' then
      metadata.table_columns(col_idx).inf_ref_define_code := metadata.table_columns(col_idx).inf_ref_define_code ||'
        l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := round(generator_count/dist_' || substr(metadata.table_columns(col_idx).column_name, 1, 15) ||');';
    elsif metadata.table_columns(col_idx).inf_ref_type = 'range' then
      metadata.table_columns(col_idx).inf_ref_define_code := metadata.table_columns(col_idx).inf_ref_define_code ||'
        l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := generator_count;
        l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := 0;
        l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := substr(dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) ||', 1, instr(dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) ||', '','') - 1);
        l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := substr(dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) ||', instr(dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) ||', '','') + 1);';
    elsif metadata.table_columns(col_idx).inf_ref_type = 'weighted' then
      metadata.table_columns(col_idx).inf_ref_define_code := metadata.table_columns(col_idx).inf_ref_define_code ||'
        l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := generator_count;
        l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := 0;
        l_ref_weighted_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' varchar2(4000) := dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) || ';
        l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := 1;
        l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' number := 1;';
    end if;
    metadata.table_columns(col_idx).inf_ref_define_code := metadata.table_columns(col_idx).inf_ref_define_code ||'
      l_ref_cur_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||' sys_refcursor;
      l_ref_stmt_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||' varchar2(4000) := ''
        select ' || metadata.table_columns(col_idx).column_def_ref_col || ' as ref_dist_col
        from (
          select ' || metadata.table_columns(col_idx).column_def_ref_col || '
          from ' || metadata.table_columns(col_idx).column_def_ref_tab || '
          order by dbms_random.value
        )
        where rownum <= ''|| generator_count;
    ';

    -- Now we build the loading of the reference data code.
    -- Only load the lists of data if the data being referenced exists. If it does not exist
    -- have exception code ready in the value block to just use a default generator.
    metadata.table_columns(col_idx).inf_ref_loader_code := '
      begin
        if dbms_assert.sql_object_name('''|| metadata.table_columns(col_idx).column_def_ref_tab ||''') = ''' || metadata.table_columns(col_idx).column_def_ref_tab || ''' and dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) || ' is not null then
          open l_ref_cur_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||' for l_ref_stmt_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||';
          loop
            fetch l_ref_cur_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||' into l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx;
            exit when l_ref_cur_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||'%notfound;';
    if metadata.table_columns(col_idx).inf_ref_type = 'simple' then
      metadata.table_columns(col_idx).inf_ref_loader_code := metadata.table_columns(col_idx).inf_ref_loader_code || '
          l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx) := dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) ||';
      ';
    elsif metadata.table_columns(col_idx).inf_ref_type = 'range' then
      -- For range we do a r_natural based on input. Always keeping track of total
      -- count so we only generate the required rows in the child table.
      metadata.table_columns(col_idx).inf_ref_loader_code := metadata.table_columns(col_idx).inf_ref_loader_code || '
            l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx) := core_random.r_natural(l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ', l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ');';
      
      metadata.table_columns(col_idx).inf_ref_loader_code := metadata.table_columns(col_idx).inf_ref_loader_code || '
            l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' + l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx);
            if l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' > l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
              l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := 1;
              l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ';
            elsif l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' > l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
              l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ';
            end if;
            if l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' >= l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
              exit;
            end if;';
    elsif metadata.table_columns(col_idx).inf_ref_type = 'weighted' then
      -- for weighted we do a random_util pick weighted.
      metadata.table_columns(col_idx).inf_ref_loader_code := metadata.table_columns(col_idx).inf_ref_loader_code || '
            l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx) := util_random.ru_pickone_weighted(l_ref_weighted_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ');';
      
      metadata.table_columns(col_idx).inf_ref_loader_code := metadata.table_columns(col_idx).inf_ref_loader_code || '
            l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' + l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx);
            if l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' > l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
              l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := 1;
              l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := l_ref_min_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ';
            elsif l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' > l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
              l_ref_max_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' := l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ';
            end if;
            if l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' >= l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
              exit;
            end if;';
    end if;
    metadata.table_columns(col_idx).inf_ref_loader_code := metadata.table_columns(col_idx).inf_ref_loader_code || '
          end loop;
          close l_ref_cur_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) ||';
          if l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' < l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' then
            l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list.last) := l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list.last) + (l_ref_distr_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ' - l_ref_track_' || substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || ');
          end if;
          l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx := l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list.first;
        end if;
        exception
          when others then
            null;
      end;
    ';

    -- Now we build the logic of reference values
    metadata.table_columns(col_idx).inf_ref_logic_code := '
            begin
              if dbms_assert.sql_object_name('''|| metadata.table_columns(col_idx).column_def_ref_tab ||''') = ''' || metadata.table_columns(col_idx).column_def_ref_tab || ''' and dist_'|| substr(metadata.table_columns(col_idx).column_name, 1, 15) || ' is not null then
                l_ret_var.' || metadata.table_columns(col_idx).column_name || ' := l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx;
                l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx) := l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx) - 1;
                if l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx) = 0 then
                  l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx := l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list.next(l_'|| substr(metadata.table_columns(col_idx).column_def_ref_col, 1, 15) || '_list_idx);
                end if;
              else';
    if metadata.table_columns(col_idx).inf_col_generator_args is not null then
      metadata.table_columns(col_idx).inf_ref_logic_code := metadata.table_columns(col_idx).inf_ref_logic_code ||'
                  l_ret_var.' || metadata.table_columns(col_idx).column_name || ' := '|| metadata.table_columns(col_idx).inf_col_generator || '(' || metadata.table_columns(col_idx).inf_col_generator_args || ');';
    else
      metadata.table_columns(col_idx).inf_ref_logic_code := metadata.table_columns(col_idx).inf_ref_logic_code ||'
                  l_ret_var.' || metadata.table_columns(col_idx).column_name || ' := '|| metadata.table_columns(col_idx).inf_col_generator || ';';
    end if;
    metadata.table_columns(col_idx).inf_ref_logic_code := metadata.table_columns(col_idx).inf_ref_logic_code ||'
              end if;
              exception
                when others then
    ';
    if metadata.table_columns(col_idx).inf_col_generator_args is not null then
      metadata.table_columns(col_idx).inf_ref_logic_code := metadata.table_columns(col_idx).inf_ref_logic_code ||'
                  l_ret_var.' || metadata.table_columns(col_idx).column_name || ' := '|| metadata.table_columns(col_idx).inf_col_generator || '(' || metadata.table_columns(col_idx).inf_col_generator_args || ');';
    else
      metadata.table_columns(col_idx).inf_ref_logic_code := metadata.table_columns(col_idx).inf_ref_logic_code ||'
                  l_ret_var.' || metadata.table_columns(col_idx).column_name || ' := '|| metadata.table_columns(col_idx).inf_col_generator || ';';
    end if;
    metadata.table_columns(col_idx).inf_ref_logic_code := metadata.table_columns(col_idx).inf_ref_logic_code ||'
            end;
    ';

  end infer_foreign_key_col;

  procedure infer_check_constraint_col (
    metadata              in out nocopy         testdata_ninja.main_tab_meta
    , col_idx             in                    number
  )

  as

    cursor get_all_check_cons is
      select 
        a.table_name
        , b.column_name
        , a.search_condition_vc 
      from 
        user_constraints a
      join
        user_cons_columns b on a.table_name = b.table_name and a.constraint_name = b.constraint_name
      where 
        a.constraint_type = 'C'
      and
        b.column_name = metadata.table_columns(col_idx).column_name
      and
        a.table_name = metadata.table_name;

    l_cleaned_check_cons      varchar2(32000);
    l_reference_others        boolean := false;
    l_reference_own           boolean := false;

  begin
      
      for i in get_all_check_cons loop
        -- Removing crappy chars from check constraint code.
        l_cleaned_check_cons := trim(replace(l_cleaned_check_cons, '"'));
        -- Check col references
        for i in 1..metadata.table_columns.count loop
          if metadata.table_columns(i).column_name != metadata.table_columns(col_idx).column_name then
            if instr(upper(l_cleaned_check_cons), metadata.table_columns(i).column_name) > 0 then
              -- Referencing others
              l_reference_others := true;
            end if;
          else
            if instr(upper(l_cleaned_check_cons), metadata.table_columns(i).column_name) > 0 then
              -- Referencing others
              l_reference_own := true;
            end if;
          end if;
        end loop;

        if l_reference_own and not l_reference_others then
          -- Only dealing with own column
          if instr(upper(l_cleaned_check_cons), metadata.table_columns(col_idx).column_name || ' IS NOT NULL') > 0 then
            -- Make sure column is not nullable.
            metadata.table_columns(col_idx).inf_col_generator_nullable := null;
          end if;
          if instr(upper(l_cleaned_check_cons), metadata.table_columns(col_idx).column_name || ' IN (') > 0 then
            -- If not already a list, convert this column to a limited value list as per check constraint.
            null;
          end if;
        elsif l_reference_others and not l_reference_own then
          -- Only dealing with others
          null;
        elsif l_reference_others and l_reference_own then
          -- Dealing with both own and others
          null;
        end if;
      end loop;
  
  end infer_check_constraint_col;

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
      -- If column is a foreign key, we need to investigate the distribution for this.
      if metadata.table_columns(c).column_is_foreign = 1 then
        infer_foreign_key_col(metadata, c);
      end if;
      -- Set the final assumptions and generic settings.
      set_final_col_assumptions(metadata, c);
    end loop;

    -- Now that we have build the initial assumptions
    -- and inferred generators, we make another pass through
    -- to make sure we can satisfy check constraints. The reason
    -- we need a second pass is that check constraints could have been
    -- referencing columns not yet inferred and so no data yet.
    for c in 1..metadata.table_columns.count loop
      if metadata.table_columns(c).column_is_check >= 1 then
        infer_check_constraint_col(metadata, c);
      end if;
    end loop;

    dbms_application_info.set_action(null);

    /*exception
      when others then
        dbms_application_info.set_action(null);
        raise;*/

  end infer_generators;

begin

  dbms_application_info.set_client_info('testdata_data_infer');
  dbms_session.set_identifier('testdata_data_infer');

end testdata_data_infer;
/
