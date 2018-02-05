create or replace package body testdata_ninja

as

  -- Keep track of output values.
  type track_output_tab is table of varchar2(128) index by varchar2(128);
  l_output_track          track_output_tab;
  -- Keep track of output order for topo sort.
  type track_output_ord_tab is table of number index by varchar2(128);
  l_output_order_track    track_output_ord_tab;
  -- Keep track of input values.
  type track_input_rec is record (
    input_position        number
    , input_name          varchar2(128)
    , draw_from_col       varchar2(128)
    , draw_from_col_num   number
  );
  type track_input_tab1 is table of track_input_rec;
  type track_input_tab2 is table of track_input_tab1;
  l_input_track           track_input_tab2;

  function guess_data_generator (
    data_type                   in        varchar2
    , column_name               in        varchar2
    , value_example             in        varchar2 default null
    , value_low                 in        raw default null
    , value_high                in        raw default null
  )
  return varchar2

  as

    l_ret_var               varchar2(500) := null;
    l_guess_idx             varchar2(128);
    type seed_vals_varchar_tab is table of varchar2(4000) index by varchar2(128);
    l_guess_varchar_seed_vals       seed_vals_varchar_tab;
    l_guess_number_seed_vals        seed_vals_varchar_tab;
    l_guess_date_seed_vals          seed_vals_varchar_tab;
    l_guess_range_low_num           number := null;
    l_guess_range_high_num          number := null;
    l_guess_range_high_char         varchar2(32000) := null;
    l_guess_range_low_char          varchar2(32000) := null;
    l_guess_range_low_date          date := null;
    l_guess_range_high_date         date := null;

  begin

    dbms_application_info.set_action('guess_data_generator');

    if value_low is not null then
      case data_type
        when 'NUMBER' then l_guess_range_low_num := utl_raw.cast_to_number(value_low);
        when 'VARCHAR2' then l_guess_range_low_char := utl_raw.cast_to_varchar2(value_low);
        when 'DATE' then l_guess_range_low_date := to_date(rtrim(to_char(100*(to_number(substr(value_low,1,2),'XX')-100)
                                                    + (to_number(substr(value_low,3,2),'XX')-100),'fm0000')||'-'||
                                                    to_char(to_number(substr(value_low,5,2),'XX'),'fm00')||'-'||
                                                    to_char(to_number(substr(value_low,7,2),'XX'),'fm00')||' '||
                                                    to_char(to_number(substr(value_low,9,2),'XX')-1,'fm00')||':'||
                                                    to_char(to_number(substr(value_low,11,2),'XX')-1,'fm00')||':'||
                                                    to_char(to_number(substr(value_low,13,2),'XX')-1,'fm00')), 'YYYY-MM-DD HH24:MI:SS');
        else null;
      end case;
    end if;

    if value_high is not null then
      case data_type
        when 'NUMBER' then l_guess_range_high_num := utl_raw.cast_to_number(value_high);
        when 'VARCHAR2' then l_guess_range_high_char := utl_raw.cast_to_varchar2(value_high);
        when 'DATE' then l_guess_range_high_date := to_date(rtrim(to_char(100*(to_number(substr(value_high,1,2),'XX')-100)
                                                    + (to_number(substr(value_high,3,2),'XX')-100),'fm0000')||'-'||
                                                    to_char(to_number(substr(value_high,5,2),'XX'),'fm00')||'-'||
                                                    to_char(to_number(substr(value_high,7,2),'XX'),'fm00')||' '||
                                                    to_char(to_number(substr(value_high,9,2),'XX')-1,'fm00')||':'||
                                                    to_char(to_number(substr(value_high,11,2),'XX')-1,'fm00')||':'||
                                                    to_char(to_number(substr(value_high,13,2),'XX')-1,'fm00')), 'YYYY-MM-DD HH24:MI:SS');
        else null;
      end case;
    end if;

    l_guess_varchar_seed_vals('person_random.r_firstname') := 'FNAME,FIRSTNAME,FIRST_NAME';
    l_guess_varchar_seed_vals('person_random.r_lastname') := 'LNAME,LASTNAME,LAST_NAME,ENAME';
    l_guess_varchar_seed_vals('person_random.r_name') := 'NAME,FULLNAME,FULL_NAME';
    l_guess_number_seed_vals('person_random.r_salary') := 'SALARY,SAL,BONUS,PAY';
    l_guess_number_seed_vals('finance_random.r_amount#[low],[high]') := 'PRICE,ORDER,PAYMENT,COST';
    l_guess_varchar_seed_vals('location_random.r_country#true') := 'CNTRY,COUNTRY,CTRY';
    l_guess_varchar_seed_vals('person_random.r_jobtitle') := 'JOB,TITLE';
    l_guess_varchar_seed_vals('location_random.r_city') := 'LOCATION,LOC,CITY,TOWN';
    l_guess_date_seed_vals('time_random.r_datebetween#to_date(''[low]'',''DD-MON-YYYY HH24:MI:SS''),to_date(''[high]'',''DD-MON-YYYY HH24:MI:SS'')') := 'HIREDATE,BIRTHDAY,BDAY';

    if value_example is null then
      -- Only guess using type and name.
      if data_type = 'VARCHAR2' then
        l_guess_idx := l_guess_varchar_seed_vals.first;
        while l_guess_idx is not null loop
          if util_random.ru_inlist(l_guess_varchar_seed_vals(l_guess_idx), upper(column_name)) then
            l_ret_var := l_guess_idx;
            if l_guess_range_low_char is not null then
              -- We always have both low and high when it is not null. So automatically replace both.
              l_ret_var := replace(replace(l_ret_var, '[low]', l_guess_range_low_char), '[high]', l_guess_range_high_char);
            else
              l_ret_var := nvl(substr(l_ret_var, 1, instr(l_ret_var, '#') - 1), l_ret_var);
            end if;
            exit;
          end if;
          l_guess_idx := l_guess_varchar_seed_vals.next(l_guess_idx);
        end loop;
      elsif data_type = 'NUMBER' then
        l_guess_idx := l_guess_number_seed_vals.first;
        while l_guess_idx is not null loop
          if util_random.ru_inlist(l_guess_number_seed_vals(l_guess_idx), upper(column_name)) then
            l_ret_var := l_guess_idx;
            if l_guess_range_low_num is not null then
              -- We always have both low and high when it is not null. So automaticall replace both.
              l_ret_var := replace(replace(l_ret_var, '[low]', l_guess_range_low_num), '[high]', l_guess_range_high_num);
            else
              l_ret_var := nvl(substr(l_ret_var, 1, instr(l_ret_var, '#') - 1), l_ret_var);
            end if;
            exit;
          end if;
          l_guess_idx := l_guess_number_seed_vals.next(l_guess_idx);
        end loop;
      elsif data_type = 'DATE' then
        l_guess_idx := l_guess_date_seed_vals.first;
        while l_guess_idx is not null loop
          if util_random.ru_inlist(l_guess_date_seed_vals(l_guess_idx), upper(column_name)) then
            l_ret_var := l_guess_idx;
            if l_guess_range_low_date is not null then
              -- We always have both low and high when it is not null. So automaticall replace both.
              l_ret_var := replace(replace(l_ret_var, '[low]', l_guess_range_low_date), '[high]', l_guess_range_high_date);
            else
              l_ret_var := nvl(substr(l_ret_var, 1, instr(l_ret_var, '#') - 1), l_ret_var);
            end if;
            exit;
          end if;
          l_guess_idx := l_guess_date_seed_vals.next(l_guess_idx);
        end loop;
      end if;
    end if;

    dbms_application_info.set_action(null);

    return l_ret_var;

    /* exception
      when others then
        dbms_application_info.set_action(null);
        raise; */

  end guess_data_generator;

  function parse_generator_cols (
    column_metadata             in        varchar2
    , column_order              out       topological_ninja.topo_number_list
  )
  return generator_columns

  as

    l_ret_var               generator_columns := generator_columns();
    l_ret_idx               number;
    l_column_count          number := regexp_count(column_metadata, '@') + 1;
    l_tmp_column            varchar2(4000);
    l_tmp_reference         varchar2(4000);
    l_tmp_generated         varchar2(4000);
    l_reference_replace     number;
    l_tmp_pkg_name          varchar2(128);
    l_tmp_fnc_name          varchar2(128);

    l_dependencies          topological_ninja.topo_dependency_list;
    l_all_cols_sorted       topological_ninja.topo_number_list := topological_ninja.topo_number_list();

    cursor get_inputs(pkg_name varchar2, fnc_name varchar2) is
      select
        argument_name
        , position
      from
        all_arguments
      where
        object_name = upper(fnc_name)
      and
        package_name = upper(pkg_name)
      and
        in_out = 'IN'
      order by
        position;

  begin

    dbms_application_info.set_action('parse_generator_cols');

    -- First extract generator to column id and inputs to generators.
    for i in 1..l_column_count loop
      l_all_cols_sorted.extend(1);
      l_all_cols_sorted(l_all_cols_sorted.count) := i;
      l_tmp_column := util_random.ru_extract(column_metadata, i, '@');
      if substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) not in ('£', '~', '^')  then
        -- We have a generated column. Save the generator name, for use in auto input reference.
        l_tmp_fnc_name := upper(substr(util_random.ru_extract(l_tmp_column, 3, '#'), instr(util_random.ru_extract(l_tmp_column, 3, '#'), '.') + 1));
        l_output_track(l_tmp_fnc_name) := util_random.ru_extract(l_tmp_column, 1, '#');
        l_output_order_track(l_tmp_fnc_name) := i;
      end if;
    end loop;

    l_input_track := track_input_tab2();
    l_input_track.extend(l_column_count);
    -- initialize sub table type.
    for i in 1..l_input_track.count() loop
      l_input_track(i) := track_input_tab1();
    end loop;

    -- Next we map input parameters to generators.
    for i in 1..l_column_count loop
      l_tmp_column := util_random.ru_extract(column_metadata, i, '@');
      if substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) not in ('£', '~', '^')  then
        -- We have a generated column. Save the generator name, for use in auto input reference.
        -- Get column generator components.
        l_tmp_pkg_name := upper(substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, instr(util_random.ru_extract(l_tmp_column, 3, '#'), '.') - 1));
        l_tmp_fnc_name := upper(substr(util_random.ru_extract(l_tmp_column, 3, '#'), instr(util_random.ru_extract(l_tmp_column, 3, '#'), '.') + 1));
        for y in get_inputs(l_tmp_pkg_name, l_tmp_fnc_name) loop
          if l_output_track.exists(y.argument_name) then
            l_input_track(i).extend(1);
            l_input_track(i)(l_input_track(i).count).input_name := y.argument_name;
            l_input_track(i)(l_input_track(i).count).input_position := y.position;
            l_input_track(i)(l_input_track(i).count).draw_from_col := l_output_track(y.argument_name);
            l_input_track(i)(l_input_track(i).count).draw_from_col_num := l_output_order_track(l_tmp_fnc_name);
            -- my_dependencies(l_input_track(i)(l_input_track(i).count).input_position) := l_input_track(i)(l_input_track(i).count).draw_from_col_num;
            l_dependencies(l_output_order_track(l_tmp_fnc_name)) := y.position;
            -- dbms_output.put_line(l_tmp_fnc_name || '(' || l_output_order_track(l_tmp_fnc_name) || ') is dependent on ' || l_output_track(y.argument_name) || '(' || l_output_track(l_tmp_fnc_name) || ')');
          end if;
        end loop;
      end if;
    end loop;

    column_order := topological_ninja.f_s(dependency_list => l_dependencies, full_list_num => l_all_cols_sorted);
    for i in 1..column_order.count loop
      dbms_output.put_line('#' || i || ': ' || column_order(i));
    end loop;

    for i in 1..l_column_count loop
      l_tmp_column := util_random.ru_extract(column_metadata, i, '@');
      l_ret_var.extend(1);
      l_ret_idx := l_ret_var.count;
      -- Set the basics
      l_ret_var(l_ret_idx).column_name := util_random.ru_extract(l_tmp_column, 1, '#');
      l_ret_var(l_ret_idx).data_type := util_random.ru_extract(l_tmp_column, 2, '#');
      -- Check generator type.
      if substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '£' then
        -- This is a reference field.
        l_ret_var(l_ret_idx).column_type := 'reference field';
        l_tmp_reference := util_random.ru_extract(l_tmp_column, 3, '#');
        l_ret_var(l_ret_idx).reference_table := substr(util_random.ru_extract(l_tmp_reference, 1, '¤'), 2);
        l_ret_var(l_ret_idx).reference_column := util_random.ru_extract(l_tmp_reference, 2, '¤');
        l_ret_var(l_ret_idx).ref_dist_type := util_random.ru_extract(l_tmp_reference, 3, '¤');
        if length(util_random.ru_extract(l_tmp_reference, 4, '¤')) != length(l_tmp_reference) then
          l_ret_var(l_ret_idx).ref_dist_default := util_random.ru_extract(l_tmp_reference, 4, '¤');
        else
          if l_ret_var(l_ret_idx).ref_dist_type = 'simple' then
            l_ret_var(l_ret_idx).ref_dist_default := '1';
          elsif l_ret_var(l_ret_idx).ref_dist_type = 'range' then
            l_ret_var(l_ret_idx).ref_dist_default := '1,5';
          elsif l_ret_var(l_ret_idx).ref_dist_type = 'weighted' then
            l_ret_var(l_ret_idx).ref_dist_default := '2~0.5^4~0.5';
          end if;
        end if;
        -- Build the definition code for the reference field.
        l_ret_var(l_ret_idx).ref_define_code := '
          type t_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_c_tab is table of number index by varchar2(4000);
          l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list t_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_c_tab;
          l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx varchar2(4000);';

        if l_ret_var(l_ret_idx).ref_dist_type = 'simple' then
          l_ret_var(l_ret_idx).ref_define_code := l_ret_var(l_ret_idx).ref_define_code ||'
            l_ref_distr_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' number := round(generator_count/dist_' || substr(l_ret_var(l_ret_idx).column_name, 1, 15) ||');';
        elsif l_ret_var(l_ret_idx).ref_dist_type in ('range', 'weighted') then
          l_ret_var(l_ret_idx).ref_define_code := l_ret_var(l_ret_idx).ref_define_code ||'
            l_ref_distr_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' number := generator_count;
            l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' number := 0;
            l_ref_min_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' number := substr(dist_'|| substr(l_ret_var(l_ret_idx).column_name, 1, 15) ||', 1, instr(dist_'|| substr(l_ret_var(l_ret_idx).column_name, 1, 15) ||', '','') - 1);
            l_ref_max_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' number := substr(dist_'|| substr(l_ret_var(l_ret_idx).column_name, 1, 15) ||', instr(dist_'|| substr(l_ret_var(l_ret_idx).column_name, 1, 15) ||', '','') + 1);';
        end if;
        l_ret_var(l_ret_idx).ref_define_code := l_ret_var(l_ret_idx).ref_define_code ||'
          cursor c_ref_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) ||'(dist_in number) is
            select ' || l_ret_var(l_ret_idx).reference_column || ' as ref_dist_col
            from (
              select ' || l_ret_var(l_ret_idx).reference_column || '
              from ' || l_ret_var(l_ret_idx).reference_table || '
              order by dbms_random.value
            )
            where rownum <= dist_in;
        ';
        -- Now we build the loading of the reference data code.
        l_ret_var(l_ret_idx).ref_loader_code := '
          -- Load reference data cursors to lists
          for i in c_ref_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) ||'(l_ref_distr_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ') loop';
        if l_ret_var(l_ret_idx).ref_dist_type = 'simple' then
          l_ret_var(l_ret_idx).ref_loader_code := l_ret_var(l_ret_idx).ref_loader_code || '
            l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(i.ref_dist_col) := dist_'|| substr(l_ret_var(l_ret_idx).column_name, 1, 15) ||';
          ';
        elsif l_ret_var(l_ret_idx).ref_dist_type in ('range', 'weighted') then
          -- For range we do a r_natural based on input. Always keeping track of total
          -- count so we only generate the required rows in the child table.
          l_ret_var(l_ret_idx).ref_loader_code := l_ret_var(l_ret_idx).ref_loader_code || '
            l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(i.ref_dist_col) := core_random.r_natural(l_ref_min_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ', l_ref_max_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ');
            l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' := l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' + l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(i.ref_dist_col);
            if l_ref_min_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' > l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' then
              l_ref_min_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' := 1;
              l_ref_max_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' := l_ref_min_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ';
            elsif l_ref_max_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' > l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' then
              l_ref_max_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' := l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ';
            end if;
            if l_ref_track_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' >= l_ref_distr_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' then
              exit;
            end if;';
        end if;
        l_ret_var(l_ret_idx).ref_loader_code := l_ret_var(l_ret_idx).ref_loader_code || '
          end loop;
          -- Set the index
          l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx := l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list.first;
        ';
        -- Now we build the logic of reference values
        l_ret_var(l_ret_idx).ref_logic_code := '
            l_ret_var.' || l_ret_var(l_ret_idx).column_name || ' := l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx;
            l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx) := l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx) - 1;
            if l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx) = 0 then
              l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx := l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list.next(l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx);
            end if;
        ';
      elsif substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '~' then
        l_ret_var(l_ret_idx).column_type := 'fixed';
        l_ret_var(l_ret_idx).fixed_value := substr(util_random.ru_extract(l_tmp_column, 3, '#'), 2);
      elsif substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '^' then
        l_ret_var(l_ret_idx).column_type := 'builtin';
        l_tmp_reference := substr(util_random.ru_extract(l_tmp_column, 3, '#'), 2);
        -- Builtin elements are split by ~
        l_ret_var(l_ret_idx).builtin_type := util_random.ru_extract(l_tmp_reference, 1, '~');
        if l_ret_var(l_ret_idx).builtin_type = 'numiterate' then
          l_ret_var(l_ret_idx).builtin_function := 'util_random.ru_number_increment';
        elsif l_ret_var(l_ret_idx).builtin_type = 'datiterate' then
          l_ret_var(l_ret_idx).builtin_function := 'util_random.ru_date_increment';
        end if;
        if length(util_random.ru_extract(l_tmp_reference, 2, '~')) != length(l_tmp_reference) then
          -- startfrom is defined.
          l_ret_var(l_ret_idx).builtin_startpoint := util_random.ru_extract(l_tmp_reference, 2, '~');
        else
          if l_ret_var(l_ret_idx).builtin_type = 'numiterate' then
            l_ret_var(l_ret_idx).builtin_startpoint := '1';
          elsif l_ret_var(l_ret_idx).builtin_type = 'datiterate' then
            l_ret_var(l_ret_idx).builtin_startpoint := to_char(sysdate, 'DDMMYYYY-HH24:MI:SS');
          end if;
        end if;
        if length(util_random.ru_extract(l_tmp_reference, 3, '~')) != length(l_tmp_reference) then
          -- increment is defined
          l_ret_var(l_ret_idx).builtin_increment := util_random.ru_extract(l_tmp_reference, 3, '~');
        else
          if l_ret_var(l_ret_idx).builtin_type = 'numiterate' then
            l_ret_var(l_ret_idx).builtin_increment := '1¤5';
          elsif l_ret_var(l_ret_idx).builtin_type = 'datiterate' then
            l_ret_var(l_ret_idx).builtin_increment := 'minutes¤1¤5';
          end if;
        end if;
        -- First build the define code.
        if l_ret_var(l_ret_idx).builtin_type = 'numiterate' then
          l_ret_var(l_ret_idx).builtin_define_code := '
            l_bltin_' || l_ret_var(l_ret_idx).column_name || ' number := ' || l_ret_var(l_ret_idx).builtin_startpoint || ';';
        elsif l_ret_var(l_ret_idx).builtin_type = 'datiterate' then
          l_ret_var(l_ret_idx).builtin_define_code := '
            l_bltin_' || l_ret_var(l_ret_idx).column_name || ' date := to_date(''' || l_ret_var(l_ret_idx).builtin_startpoint || ''', ''DDMMYYYY-HH24:MI:SS'');';
        end if;
        -- Now we can build the logic.
        if l_ret_var(l_ret_idx).builtin_type = 'numiterate' then
          l_ret_var(l_ret_idx).builtin_logic_code := '
            l_bltin_' || l_ret_var(l_ret_idx).column_name || ' := ' || l_ret_var(l_ret_idx).builtin_function || '(l_bltin_' || l_ret_var(l_ret_idx).column_name || ', ' || util_random.ru_extract(l_ret_var(l_ret_idx).builtin_increment, 1, '¤') || ', ' || util_random.ru_extract(l_ret_var(l_ret_idx).builtin_increment, 2, '¤') || ');';
        elsif l_ret_var(l_ret_idx).builtin_type = 'datiterate' then
          l_ret_var(l_ret_idx).builtin_logic_code := '
            l_bltin_' || l_ret_var(l_ret_idx).column_name || ' := ' || l_ret_var(l_ret_idx).builtin_function || '(l_bltin_' || l_ret_var(l_ret_idx).column_name || ', ''' || util_random.ru_extract(l_ret_var(l_ret_idx).builtin_increment, 1, '¤') || ''', ' || util_random.ru_extract(l_ret_var(l_ret_idx).builtin_increment, 2, '¤') || ', ' || util_random.ru_extract(l_ret_var(l_ret_idx).builtin_increment, 3, '¤') || ');';
        end if;
      elsif substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '$' then
        -- We have a reference list. Do not build as a real field, only generate and store
        -- so we can reference a value from it, from generated field.
        -- If the string is enclosed in square brackets, we take it as a fixed value list,
        -- else the following string is treated as generator function and number of elements to
        -- generate for the list, separated by the ¤ character.
        l_ret_var(l_ret_idx).column_type := 'referencelist';
        if substr(util_random.ru_extract(l_tmp_column, 3, '#'), 2, 1) = '[' then
          -- Fixed list. Set referencelist values to string between the square brackets.
          l_ret_var(l_ret_idx).fixed_value := substr(util_random.ru_extract(l_tmp_column, 3, '#'), 3);
          l_ret_var(l_ret_idx).fixed_value := substr(l_ret_var(l_ret_idx).fixed_value, 1, length(l_ret_var(l_ret_idx).fixed_value) - 1);
        else
          -- Generate the list at runtime. Define the code to do so.
          null;
        end if;
      else
        l_ret_var(l_ret_idx).column_type := 'generated';
        -- First check if we allow nulls. If the generator is surrounded by parentheses
        -- then we allow nulls. The number after the closing parentheses is the percentage
        -- of rows that should be null.
        l_tmp_generated := util_random.ru_extract(l_tmp_column, 3, '#');
        if substr(l_tmp_generated, 1, 1) = '(' then
          -- Column allowed to be null.
          -- check if nullable percentage is set, else default to 10%
          if substr(l_tmp_generated, -1, 1) = ')' then
            -- No nullable defined.
            l_ret_var(l_ret_idx).generator_nullable := 10;
          else
            l_ret_var(l_ret_idx).generator_nullable := substr(l_tmp_generated, instr(l_tmp_generated, ')') + 1);
          end if;
          l_ret_var(l_ret_idx).generator := substr(l_tmp_generated, 2, instr(l_tmp_generated, ')') - 2);
        else
          l_ret_var(l_ret_idx).generator := l_tmp_generated;
          l_ret_var(l_ret_idx).generator_nullable := null;
        end if;
        if length(util_random.ru_extract(l_tmp_column, 4, '#')) != length(l_tmp_column) then
          -- Manually specified input variables always override auto replace.
          l_ret_var(l_ret_idx).generator_args := util_random.ru_extract(l_tmp_column, 4, '#');
          l_reference_replace := instr(l_ret_var(l_ret_idx).generator_args, '%%');
          while l_reference_replace > 0 loop
            -- Start replacing backwards reference fields
            l_ret_var(l_ret_idx).generator_args := substr(l_ret_var(l_ret_idx).generator_args, 1, l_reference_replace -1) || 'l_ret_var.' || substr(l_ret_var(l_ret_idx).generator_args, l_reference_replace + 2);
            -- Remove end reference field marker
            l_reference_replace := instr(l_ret_var(l_ret_idx).generator_args, '%%');
            l_ret_var(l_ret_idx).generator_args := substr(l_ret_var(l_ret_idx).generator_args, 1, l_reference_replace -1) || substr(l_ret_var(l_ret_idx).generator_args, l_reference_replace + 2);
            -- Get the next marker.
            l_reference_replace := instr(l_ret_var(l_ret_idx).generator_args, '%%');
          end loop;
        else
          -- Let us check if any of the inputs to this column is generated from other columns.
          for y in 1..l_input_track(i).count loop
            if length(l_ret_var(l_ret_idx).generator_args) > 0 then
              l_ret_var(l_ret_idx).generator_args := l_ret_var(l_ret_idx).generator_args || ', ';
            end if;
            l_ret_var(l_ret_idx).generator_args := l_ret_var(l_ret_idx).generator_args || l_input_track(i)(y).input_name || ' => ' || 'l_ret_var.' || l_input_track(i)(y).draw_from_col;
          end loop;
        end if;
      end if;
    end loop;

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end parse_generator_cols;

  function parse_cols_from_table (
    tab_name                in        varchar2
  )
  return generator_columns

  as

    l_ret_var               generator_columns := generator_columns();
    l_curr_idx              number;
    l_curr_stats_idx        number;
    l_guessed_generator     varchar2(4000);
    l_base_table_info       user_tables%rowtype;
    type tab_cols_tab is table of user_tab_cols%rowtype;
    l_base_table_cols_info  tab_cols_tab := tab_cols_tab();
    l_base_table_stats      user_tab_statistics%rowtype;
    type tab_cols_stats_tab is table of user_tab_col_statistics%rowtype;
    l_base_table_col_stats  tab_cols_stats_tab := tab_cols_stats_tab();

    -- Working assumptions.
    l_is_unique             boolean := false;
    l_str_start_len         number := 4;
    l_str_stop_len          number := 20;

    cursor get_col_info is
      select * from all_tab_cols
      where table_name = upper(tab_name)
      order by column_id;

    cursor get_col_stats_info is
      select * from user_tab_col_statistics
      where table_name = upper(tab_name);

    cursor get_tab_constraints is
      select
        a.table_name
        , a.column_name
        , a.constraint_name
        , c.owner
        , c.r_owner
        , c_pk.table_name r_table_name
        , c_pk.constraint_name r_pk
      from
        user_cons_columns a
      join
        user_constraints c on a.constraint_name = c.constraint_name
      join
        user_constraints c_pk on c.r_constraint_name = c_pk.constraint_name
      where
        c.constraint_type = 'R'
      and
        a.table_name = upper(tab_name);

    type cons_list_tab is table of get_tab_constraints%rowtype;

    l_base_table_cons_info          cons_list_tab := cons_list_tab();

    l_all_meta                      main_tab_meta;

  begin

    dbms_application_info.set_action('parse_cols_from_table');

    if dbms_assert.sql_object_name(upper(tab_name)) = upper(tab_name) then
      -- The table exists, and if not this will throw exception.
      -- Get all the current information we have on the table into variables
      -- for use in generating a format as close to real life as possible.
      l_all_meta.table_name := upper(tab_name);
      -- BASE INFO
      select * into l_all_meta.table_base_data from all_tables where table_name = upper(tab_name);
      l_all_meta.table_columns := main_tab_cols();
      for i in get_col_info loop
        l_all_meta.table_columns.extend(1);
        l_all_meta.table_columns(l_all_meta.table_columns.count).column_name := i.column_name;
        l_all_meta.table_columns(l_all_meta.table_columns.count).column_type := i.data_type;
        l_all_meta.table_columns(l_all_meta.table_columns.count).column_base_data := i;
        select * into l_all_meta.table_columns(l_all_meta.table_columns.count).column_base_stats
        from all_tab_col_statistics
        where table_name = upper(tab_name)
        and column_name = i.column_name;
      end loop;
      -- STATISTICS INFO
      select * into l_all_meta.table_base_stats from all_tab_statistics where table_name = upper(tab_name);
      -- CONSTRAINTS INFO
      /* for i in get_tab_constraints loop
        l_base_table_cons_info.extend(1);
        l_base_table_cons_info(l_base_table_cons_info.count) := i;
      end loop; */

      -- NEW WAY
      testdata_data_infer.infer_generators(metadata => l_all_meta);

      -- Loop over all the columns.
      for i in 1..l_all_meta.table_columns.count loop
        -- First extend
        l_ret_var.extend(1);

        -- Base column settings.
        l_ret_var(i).column_name := l_all_meta.table_columns(i).column_name;
        l_ret_var(i).column_type := l_all_meta.table_columns(i).inf_col_type;

        -- Data type
        case l_all_meta.table_columns(i).column_type
          when 'VARCHAR2' then l_ret_var(i).data_type := l_all_meta.table_columns(i).column_base_data.data_type || '(' || l_all_meta.table_columns(i).column_base_data.data_length || ')';
          else l_ret_var(i).data_type := l_all_meta.table_columns(i).column_base_data.data_type;
        end case;

        -- Set the data generator values.
        if l_ret_var(i).column_type = 'generated' then
          l_ret_var(i).generator := l_all_meta.table_columns(i).inf_col_generator;
          l_ret_var(i).generator_args := l_all_meta.table_columns(i).inf_col_generator_args;
          if l_all_meta.table_columns(i).inf_col_generator_nullable is not null then
            l_ret_var(i).generator_nullable := l_all_meta.table_columns(i).inf_col_generator_nullable;
          end if;
        elsif l_ret_var(i).column_type = 'fixed' then
          l_ret_var(i).fixed_value := l_all_meta.table_columns(i).inf_fixed_value;
        end if;

      end loop;

    end if;

    dbms_application_info.set_action(null);

    return l_ret_var;

    /* exception
      when others then
        dbms_application_info.set_action(null);
        raise; */

  end parse_cols_from_table;

  procedure generator_create (
    generator_name              in        varchar2
    , generator_format          in        varchar2 default null
    , generator_table           in        varchar2 default null
  )

  as

    -- Vars
    l_generator_pkg_head        varchar2(32000);
    l_generator_pkg_body        varchar2(32000);
    l_generator_columns         generator_columns;
    l_generator_first_col       boolean := true;
    l_column_order              topological_ninja.topo_number_list := topological_ninja.topo_number_list();
    l_build_idx                 number;

  begin

    dbms_application_info.set_action('generator_create');

    if generator_table is null and generator_format is not null then
      l_generator_columns := parse_generator_cols(generator_format, l_column_order);
    elsif generator_format is null and generator_table is not null then
      l_generator_columns := parse_cols_from_table(generator_table);
    end if;

    l_generator_pkg_head := 'create or replace package tdg_'|| generator_name ||'
      as
        g_default_generator_rows      number := '|| g_default_generator_rows ||';

        type csv_rec is record (
          csv    varchar2(4000)
        );
        type csv_tab is table of csv_rec;

        type '|| generator_name ||'_rec is record (
        ';

        for i in 1..l_generator_columns.count loop
          if l_generator_columns(i).column_type != 'referencelist' then
            if l_generator_first_col then
              l_generator_pkg_head := l_generator_pkg_head || l_generator_columns(i).column_name || ' ' || l_generator_columns(i).data_type;
              l_generator_first_col := false;
            else
              l_generator_pkg_head := l_generator_pkg_head || ', ' || l_generator_columns(i).column_name || ' ' || l_generator_columns(i).data_type;
            end if;
          end if;
        end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
        );
        type '|| generator_name ||'_tab is table of '|| generator_name ||'_rec;

        function '|| generator_name ||' (
          generator_count         number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        if l_generator_columns(i).ref_dist_type = 'simple' then
          l_generator_pkg_head := l_generator_pkg_head || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
        else
          l_generator_pkg_head := l_generator_pkg_head || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   varchar2 default ''' || l_generator_columns(i).ref_dist_default || '''';
        end if;
      end if;
    end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
        )
        return '|| generator_name ||'_tab
        pipelined;

        procedure to_table (
          table_name              varchar2
          , generator_count       number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        if l_generator_columns(i).ref_dist_type = 'simple' then
          l_generator_pkg_head := l_generator_pkg_head || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
        else
          l_generator_pkg_head := l_generator_pkg_head || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   varchar2 default ''' || l_generator_columns(i).ref_dist_default || '''';
        end if;
      end if;
    end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
          , add_foreign_keys      boolean default false
          , overwrite             boolean default false
        );

        function to_csv (
          generator_count         number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        if l_generator_columns(i).ref_dist_type = 'simple' then
          l_generator_pkg_head := l_generator_pkg_head || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
        else
          l_generator_pkg_head := l_generator_pkg_head || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   varchar2 default ''' || l_generator_columns(i).ref_dist_default || '''';
        end if;
      end if;
    end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
          , delimiter         varchar2 default '',''
          , optional_enclose  varchar2 default ''''
          , date_format       varchar2 default ''dd-mon-yyyy hh24:mi:ss''
          , include_header    number default 1
          , custom_header     varchar2 default null
          , include_footer    number default 0
          , custom_footer     varchar2 default null
        )
        return csv_tab
        pipelined;

      end tdg_'|| generator_name ||';';

    execute immediate l_generator_pkg_head;

    l_generator_pkg_body := 'create or replace package body tdg_'|| generator_name ||'
      as

        function to_csv (
          generator_count         number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        if l_generator_columns(i).ref_dist_type = 'simple' then
          l_generator_pkg_body := l_generator_pkg_body || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
        else
          l_generator_pkg_body := l_generator_pkg_body || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   varchar2 default ''' || l_generator_columns(i).ref_dist_default || '''';
        end if;
      end if;
    end loop;

    l_generator_pkg_body := l_generator_pkg_body || '
          , delimiter         varchar2 default '',''
          , optional_enclose  varchar2 default ''''
          , date_format       varchar2 default ''dd-mon-yyyy hh24:mi:ss''
          , include_header    number default 1
          , custom_header     varchar2 default null
          , include_footer    number default 0
          , custom_footer     varchar2 default null
        )
        return csv_tab
        pipelined

        as

          l_delimiter             varchar2(10) := '''';
          l_enclose               varchar2(10) := optional_enclose;
          l_statement             varchar2(4000) := ''select * from table(tdg_'|| generator_name ||'.'|| generator_name ||'(''|| generator_count ||''))'';
          l_cursor                integer := dbms_sql.open_cursor;
          l_table_description     dbms_sql.desc_tab;
          l_col_count             number := 0;
          l_line                  varchar2(4000) := '''';
          l_value                 varchar2(4000);
          l_ret_var               csv_rec;
          l_status                integer;
          l_rows_processed        number;

        begin

          execute immediate ''alter session set nls_date_format = "''|| date_format ||''"'';
          dbms_sql.parse(l_cursor, l_statement, dbms_sql.native);
          dbms_sql.describe_columns(l_cursor, l_col_count, l_table_description);
          for i in 1..l_col_count loop
            l_line := l_line || l_delimiter || l_enclose || l_table_description(i).col_name || l_enclose;
            dbms_sql.define_column( l_cursor, i, l_value, 4000 );
            l_delimiter := delimiter;
          end loop;
          if include_header = 1 then
            if custom_header is null then
              l_ret_var.csv := l_line;
            else
              l_ret_var.csv := custom_header;
            end if;
            pipe row(l_ret_var);
          end if;
          l_line := '''';
          l_status := dbms_sql.execute(l_cursor);
          while (dbms_sql.fetch_rows(l_cursor) > 0) loop
            l_delimiter := '''';
            for i in 1..l_col_count loop
              dbms_sql.column_value(l_cursor, i, l_value);
              l_line := l_line || l_delimiter || l_enclose || l_value || l_enclose;
              l_delimiter := delimiter;
            end loop;
            l_ret_var.csv := l_line;
            pipe row(l_ret_var);
            l_line := '''';
          end loop;

          if include_footer = 1 then
            l_rows_processed := dbms_sql.last_row_count;
            if custom_footer is null then
              l_line := ''Rows processed: '' || l_rows_processed;
              l_ret_var.csv := l_line;
            else
              l_ret_var.csv := replace(custom_footer, ''%%rows_processed%%'', l_rows_processed);
            end if;
            pipe row(l_ret_var);
          end if;

          dbms_sql.close_cursor(l_cursor);

          return;

          exception
            when others then
              raise;

        end to_csv;

        procedure to_table (
          table_name              varchar2
          , generator_count       number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        if l_generator_columns(i).ref_dist_type = 'simple' then
          l_generator_pkg_body := l_generator_pkg_body || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
        else
          l_generator_pkg_body := l_generator_pkg_body || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   varchar2 default ''' || l_generator_columns(i).ref_dist_default || '''';
        end if;
      end if;
    end loop;

    l_generator_pkg_body := l_generator_pkg_body || '
          , add_foreign_keys      boolean default false
          , overwrite             boolean default false
        )

        as

          l_to_table_stmt         varchar2(4000);
          l_drop_table_stmt       varchar2(4000);
          l_ex_not_valid_name     exception;
          l_ex_table_exists       exception;

          pragma exception_init(l_ex_not_valid_name, -44003);
          pragma exception_init(l_ex_table_exists, -00955);

        begin

          if dbms_assert.simple_sql_name(table_name) = table_name then
            l_to_table_stmt := ''create table '' || table_name || '' as select * from table(tdg_'|| generator_name ||'.'|| generator_name ||'(''|| generator_count ||''))'';
            l_drop_table_stmt := ''drop table '' || table_name || '' cascade constraints purge'';

            execute immediate l_to_table_stmt;
          end if;

          exception
            when l_ex_not_valid_name then
              raise_application_error(-20042, ''Invalid table name specified'');
            when l_ex_table_exists then
              if overwrite then
                execute immediate l_drop_table_stmt;
                execute immediate l_to_table_stmt;
              else
                raise_application_error(-20042, ''Table already exists, and overwrite is set to false'');
              end if;
            when others then
              raise;

        end to_table;

        function '|| generator_name ||' (
          generator_count         number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        if l_generator_columns(i).ref_dist_type = 'simple' then
          l_generator_pkg_body := l_generator_pkg_body || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
        else
          l_generator_pkg_body := l_generator_pkg_body || '
            , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   varchar2 default ''' || l_generator_columns(i).ref_dist_default || '''';
        end if;
      end if;
    end loop;

    l_generator_pkg_body := l_generator_pkg_body || '
        )
        return '|| generator_name ||'_tab
        pipelined

        as

          l_ret_var       '|| generator_name ||'_rec;

          -- Columns generation support';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        l_generator_pkg_body := l_generator_pkg_body || l_generator_columns(i).ref_define_code;
      elsif l_generator_columns(i).column_type = 'builtin' then
        l_generator_pkg_body := l_generator_pkg_body || l_generator_columns(i).builtin_define_code;
      end if;
    end loop;

    l_generator_pkg_body := l_generator_pkg_body || '
          cursor generator is
            select --+ materialize
              rownum
            from
              dual
            connect by
              level <= generator_count;

        begin
    ';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        l_generator_pkg_body := l_generator_pkg_body || l_generator_columns(i).ref_loader_code;
      end if;
    end loop;

    l_generator_pkg_body := l_generator_pkg_body || '
          for x in generator loop';

    -- l_column_order(i) is the index.
    for i in 1..l_generator_columns.count loop
      if l_column_order.count > 0 then
        l_build_idx := l_column_order(i);
      else
        l_build_idx := i;
      end if;
      if l_generator_columns(l_build_idx).column_type = 'reference field' then
        -- Referenced field. Run ref logic.
        l_generator_pkg_body := l_generator_pkg_body || l_generator_columns(l_build_idx).ref_logic_code;
      elsif l_generator_columns(l_build_idx).column_type = 'fixed' then
        if l_generator_columns(l_build_idx).data_type = 'number' then
          l_generator_pkg_body := l_generator_pkg_body || '
            l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := ' || l_generator_columns(l_build_idx).fixed_value || ';';
        else
          l_generator_pkg_body := l_generator_pkg_body || '
            l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := ''' || l_generator_columns(l_build_idx).fixed_value || ''';';
        end if;
      elsif l_generator_columns(l_build_idx).column_type = 'builtin' then
        l_generator_pkg_body := l_generator_pkg_body || '
          l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := l_bltin_' || l_generator_columns(l_build_idx).column_name || ';' || l_generator_columns(l_build_idx).builtin_logic_code;
      else
        if l_generator_columns(l_build_idx).column_type != 'referencelist' then
        -- Check if we need to add arguments or not and if nullable is enabled.
          if l_generator_columns(l_build_idx).generator_nullable is not null then
            if l_generator_columns(l_build_idx).generator_args is not null then
              l_generator_pkg_body := l_generator_pkg_body || '
                case when core_random.r_bool('|| l_generator_columns(l_build_idx).generator_nullable ||') then l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := null; else l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := ' || l_generator_columns(l_build_idx).generator || '(' || l_generator_columns(l_build_idx).generator_args || '); end case;';
            else
              l_generator_pkg_body := l_generator_pkg_body || '
                case when core_random.r_bool('|| l_generator_columns(l_build_idx).generator_nullable ||') then l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := null; else l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := ' || l_generator_columns(l_build_idx).generator || '; end case;';
            end if;
          else
            if l_generator_columns(l_build_idx).generator_args is not null then
              l_generator_pkg_body := l_generator_pkg_body || '
                l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := ' || l_generator_columns(l_build_idx).generator || '(' || l_generator_columns(l_build_idx).generator_args || ');';
            else
              l_generator_pkg_body := l_generator_pkg_body || '
                l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := ' || l_generator_columns(l_build_idx).generator || ';';
            end if;
          end if;
        end if;
      end if;
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

    /* exception
      when others then
        dbms_application_info.set_action(null);
        raise; */

  end generator_create;

begin

  dbms_application_info.set_client_info('testdata_ninja');
  dbms_session.set_identifier('testdata_ninja');

end testdata_ninja;
/
