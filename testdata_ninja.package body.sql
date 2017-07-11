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


  function parse_generator_cols (
    column_metadata             in        varchar2
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
          end if;
        end loop;
      end if;
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

  procedure generator_create (
    generator_name              in        varchar2
    , generator_format          in        varchar2
  )

  as

    -- Vars
    l_generator_pkg_head        varchar2(32000);
    l_generator_pkg_body        varchar2(32000);
    l_generator_columns         generator_columns;

  begin

    dbms_application_info.set_action('generator_create');

    l_generator_columns := parse_generator_cols(generator_format);

    l_generator_pkg_head := 'create or replace package tdg_'|| generator_name ||'
      as
        g_default_generator_rows      number := 100;

        type csv_rec is record (
          csv    varchar2(4000)
        );
        type csv_tab is table of csv_rec;

        type '|| generator_name ||'_rec is record (
        ';

        for i in 1..l_generator_columns.count loop
          if i = 1 then
            l_generator_pkg_head := l_generator_pkg_head || l_generator_columns(i).column_name || ' ' || l_generator_columns(i).data_type;
          else
            l_generator_pkg_head := l_generator_pkg_head || ', ' || l_generator_columns(i).column_name || ' ' || l_generator_columns(i).data_type;
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

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        -- Referenced field. Run ref logic.
        l_generator_pkg_body := l_generator_pkg_body || l_generator_columns(i).ref_logic_code;
      elsif l_generator_columns(i).column_type = 'fixed' then
        if l_generator_columns(i).data_type = 'number' then
          l_generator_pkg_body := l_generator_pkg_body || '
            l_ret_var.' || l_generator_columns(i).column_name || ' := ' || l_generator_columns(i).fixed_value || ';';
        else
          l_generator_pkg_body := l_generator_pkg_body || '
            l_ret_var.' || l_generator_columns(i).column_name || ' := ''' || l_generator_columns(i).fixed_value || ''';';
        end if;
      elsif l_generator_columns(i).column_type = 'builtin' then
        l_generator_pkg_body := l_generator_pkg_body || '
          l_ret_var.' || l_generator_columns(i).column_name || ' := l_bltin_' || l_generator_columns(i).column_name || ';' || l_generator_columns(i).builtin_logic_code;
      else
        -- Check if we need to add arguments or not and if nullable is enabled.
        if l_generator_columns(i).generator_nullable is not null then
          if l_generator_columns(i).generator_args is not null then
            l_generator_pkg_body := l_generator_pkg_body || '
              case when core_random.r_bool('|| l_generator_columns(i).generator_nullable ||') then l_ret_var.' || l_generator_columns(i).column_name || ' := null; else l_ret_var.' || l_generator_columns(i).column_name || ' := ' || l_generator_columns(i).generator || '(' || l_generator_columns(i).generator_args || '); end case;';
          else
            l_generator_pkg_body := l_generator_pkg_body || '
              case when core_random.r_bool('|| l_generator_columns(i).generator_nullable ||') then l_ret_var.' || l_generator_columns(i).column_name || ' := null; else l_ret_var.' || l_generator_columns(i).column_name || ' := ' || l_generator_columns(i).generator || '; end case;';
          end if;
        else
          if l_generator_columns(i).generator_args is not null then
            l_generator_pkg_body := l_generator_pkg_body || '
              l_ret_var.' || l_generator_columns(i).column_name || ' := ' || l_generator_columns(i).generator || '(' || l_generator_columns(i).generator_args || ');';
          else
            l_generator_pkg_body := l_generator_pkg_body || '
              l_ret_var.' || l_generator_columns(i).column_name || ' := ' || l_generator_columns(i).generator || ';';
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

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end generator_create;

begin

  dbms_application_info.set_client_info('testdata_ninja');
  dbms_session.set_identifier('testdata_ninja');

end testdata_ninja;
/
