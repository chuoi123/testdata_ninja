create or replace package body testdata_ninja

as

  -- Keep track of output values.
  type track_output_tab is table of varchar2(128) index by varchar2(128);
  l_output_track          track_output_tab;
  -- Keep track of output order for topo sort.
  type track_output_ord_tab is table of number index by varchar2(128);
  l_output_order_track    track_output_ord_tab;

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
        distinct argument_name
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

    g_input_track := track_input_tab2();
    g_input_track.extend(l_column_count);
    -- initialize sub table type.
    for i in 1..g_input_track.count() loop
      g_input_track(i) := track_input_tab1();
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
            g_input_track(i).extend(1);
            g_input_track(i)(g_input_track(i).count).input_name := y.argument_name;
            g_input_track(i)(g_input_track(i).count).input_position := y.position;
            g_input_track(i)(g_input_track(i).count).draw_from_col := l_output_track(y.argument_name);
            g_input_track(i)(g_input_track(i).count).draw_from_col_num := l_output_order_track(l_tmp_fnc_name);
            -- my_dependencies(g_input_track(i)(g_input_track(i).count).input_position) := g_input_track(i)(g_input_track(i).count).draw_from_col_num;
            l_dependencies(l_output_order_track(l_tmp_fnc_name)) := y.position;
            -- dbms_output.put_line(l_tmp_fnc_name || '(' || l_output_order_track(l_tmp_fnc_name) || ') is dependent on ' || l_output_track(y.argument_name) || '(' || l_output_track(l_tmp_fnc_name) || ')');
          end if;
        end loop;
      end if;
    end loop;

    column_order := topological_ninja.f_s(dependency_list => l_dependencies, full_list_num => l_all_cols_sorted);

    for i in 1..l_column_count loop
      l_tmp_column := util_random.ru_extract(column_metadata, i, '@');
      l_ret_var.extend(1);
      l_ret_idx := l_ret_var.count;
      -- Set the basics
      l_ret_var(l_ret_idx).column_name := util_random.ru_extract(l_tmp_column, 1, '#');
      l_ret_var(l_ret_idx).data_type := util_random.ru_extract(l_tmp_column, 2, '#');
      -- Check generator type.
      if substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '£' then
        -- We have a reference field; a foreign key to an existing table.
        testdata_piecebuilder.parse_reference(l_tmp_column, l_ret_idx, l_ret_var);
      elsif substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '~' then
        testdata_piecebuilder.parse_fixed(l_tmp_column, l_ret_idx, l_ret_var);
      elsif substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '^' then
        -- Parse the builtin information.
        testdata_piecebuilder.parse_builtin(l_tmp_column, l_ret_idx, l_ret_var);
      elsif substr(util_random.ru_extract(l_tmp_column, 3, '#'), 1, 1) = '$' then
        -- We have a reference list. Do not build as a real field, only generate and store
        -- so we can reference a value from it, from generated field.
        -- If the string is enclosed in square brackets, we take it as a fixed value list,
        -- else the following string is treated as generator function and number of elements to
        -- generate for the list, separated by the ¤ character.
        testdata_piecebuilder.parse_referencelist(l_tmp_column, l_ret_idx, l_ret_var);
      else
        testdata_piecebuilder.parse_generated(l_tmp_column, l_ret_idx, l_ret_var, g_input_track, i);
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

      -- Here is where we should build the input tracker for arguments.
      -- Just like the parser from metadata, we might have columns in this parser
      -- where we want to reference other column values.

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
        elsif l_ret_var(i).column_type = 'builtin' then
          l_ret_var(i).builtin_type := l_all_meta.table_columns(i).inf_builtin_type;
          l_ret_var(i).builtin_function := l_all_meta.table_columns(i).inf_builtin_function;
          l_ret_var(i).builtin_startpoint := l_all_meta.table_columns(i).inf_builtin_startpoint;
          l_ret_var(i).builtin_increment := l_all_meta.table_columns(i).inf_builtin_increment;
          l_ret_var(i).builtin_define_code := l_all_meta.table_columns(i).inf_builtin_define_code;
          l_ret_var(i).builtin_logic_code := l_all_meta.table_columns(i).inf_builtin_logic_code;
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
          if l_generator_first_col then
            l_generator_pkg_head := l_generator_pkg_head || l_generator_columns(i).column_name || ' ' || l_generator_columns(i).data_type;
            l_generator_first_col := false;
          else
            l_generator_pkg_head := l_generator_pkg_head || ', ' || l_generator_columns(i).column_name || ' ' || l_generator_columns(i).data_type;
          end if;
        end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
        );
        type '|| generator_name ||'_tab is table of '|| generator_name ||'_rec;

        function '|| generator_name ||' (
          generator_count         number default g_default_generator_rows
          , predictable_key       varchar2 default to_char(systimestamp,''FFSSMIHH24DDMMYYYY'') || sys_context(''USERENV'', ''SESSIONID'')';

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
          generator_count         number default g_default_generator_rows
          , predictable_key       varchar2 default to_char(systimestamp,''FFSSMIHH24DDMMYYYY'') || sys_context(''USERENV'', ''SESSIONID'')';

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
      elsif l_generator_columns(i).column_type = 'referencelist' and l_generator_columns(i).builtin_define_code is not null then
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

          dbms_random.seed(predictable_key);
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
      elsif l_generator_columns(l_build_idx).column_type = 'referencelist' then
        if l_generator_columns(l_build_idx).builtin_define_code is null then
          l_generator_pkg_body := l_generator_pkg_body || '
            l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := util_random.ru_pickone(''' || l_generator_columns(l_build_idx).fixed_value || ''');';
        else
          l_generator_pkg_body := l_generator_pkg_body || '
            l_ret_var.' || l_generator_columns(l_build_idx).column_name || ' := util_random.ru_pickone(l_bltin_' || l_generator_columns(l_build_idx).column_name || ');';
        end if;
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
