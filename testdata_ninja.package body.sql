create or replace package body testdata_ninja

as

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

  begin

    dbms_application_info.set_action('parse_generator_cols');

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
        end if;
        -- Build the definition code for the reference field.
        l_ret_var(l_ret_idx).ref_define_code := '
          type t_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_c_tab is table of number index by varchar2(4000);
          l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list t_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_c_tab;
          l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list_idx varchar2(4000);
          l_ref_distr_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ' number := round(generator_count/dist_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) ||');
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
          for i in c_ref_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) ||'(l_ref_distr_' || substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || ') loop
            l_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) || '_list(i.ref_dist_col) := dist_'|| substr(l_ret_var(l_ret_idx).reference_column, 1, 15) ||';
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
      else
        l_ret_var(l_ret_idx).column_type := 'generated';
        l_ret_var(l_ret_idx).generator := util_random.ru_extract(l_tmp_column, 3, '#');
        if length(util_random.ru_extract(l_tmp_column, 4, '#')) != length(l_tmp_column) then
          l_ret_var(l_ret_idx).generator_args := util_random.ru_extract(l_tmp_column, 4, '#');
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

    -- old structure vars.
    l_generator_pkg_head        varchar2(32000);
    l_generator_pkg_body        varchar2(32000);
    l_format_elements           number;
    l_format_element            varchar2(500);
    l_generator_elements        varchar2(1000);
    l_generator_distribution    number;
    l_key_generators            varchar2(2000);
    l_have_ref_generator        boolean := false;
    l_generator_inp_name        varchar2(30);
    l_generator_inp_val         varchar2(30);

    -- New structure vars, remove old as they are replaced.
    l_generator_columns         generator_columns;

  begin

    dbms_application_info.set_action('generator_create');

    l_generator_columns := parse_generator_cols(generator_format);

    l_generator_pkg_head := 'create or replace package tdg_'|| generator_name ||'
      as
        g_default_generator_rows      number := 10;

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
        l_generator_pkg_head := l_generator_pkg_head || '
          , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
      end if;
    end loop;

    l_generator_pkg_head := l_generator_pkg_head || '
        )
        return '|| generator_name ||'_tab
        pipelined;

      end tdg_'|| generator_name ||';';

    execute immediate l_generator_pkg_head;

    l_generator_pkg_body := 'create or replace package body tdg_'|| generator_name ||'
      as

        function '|| generator_name ||' (
          generator_count         number default g_default_generator_rows';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        l_generator_pkg_body := l_generator_pkg_body || '
          , dist_'|| substr(l_generator_columns(i).column_name, 1, 15) ||'   number default ' || l_generator_columns(i).ref_dist_default;
      end if;
    end loop;

    l_generator_pkg_body := l_generator_pkg_body || '
        )
        return '|| generator_name ||'_tab
        pipelined

        as

          l_ret_var       '|| generator_name ||'_rec;

          -- Generators';

    for i in 1..l_generator_columns.count loop
      if l_generator_columns(i).column_type = 'reference field' then
        l_generator_pkg_body := l_generator_pkg_body || l_generator_columns(i).ref_define_code;
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
      else
        l_generator_pkg_body := l_generator_pkg_body || '
          l_ret_var.' || l_generator_columns(i).column_name || ' := ' || l_generator_columns(i).generator || ';';
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
