create or replace package body testdata_piecebuilder

as

  procedure parse_builtin (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  )

  as

    l_classic_field_def       varchar2(4000);
    l_tmp_reference           varchar2(4000);

  begin

    dbms_application_info.set_action('parse_builtin');

    if length(field_spec) < 4000 then
      l_classic_field_def := to_char(field_spec);
    end if;

    generator_definition(column_idx).column_type := 'builtin';
    l_tmp_reference := substr(util_random.ru_extract(l_classic_field_def, 3, '#'), 2);
    -- Builtin elements are split by ~
    generator_definition(column_idx).builtin_type := util_random.ru_extract(l_tmp_reference, 1, '~');
    if generator_definition(column_idx).builtin_type = 'numiterate' then
      generator_definition(column_idx).builtin_function := 'util_random.ru_number_increment';
    elsif generator_definition(column_idx).builtin_type = 'datiterate' then
      generator_definition(column_idx).builtin_function := 'util_random.ru_date_increment';
    end if;
    if length(util_random.ru_extract(l_tmp_reference, 2, '~')) != length(l_tmp_reference) then
      -- startfrom is defined.
      generator_definition(column_idx).builtin_startpoint := util_random.ru_extract(l_tmp_reference, 2, '~');
    else
      if generator_definition(column_idx).builtin_type = 'numiterate' then
        generator_definition(column_idx).builtin_startpoint := '1';
      elsif generator_definition(column_idx).builtin_type = 'datiterate' then
        generator_definition(column_idx).builtin_startpoint := to_char(sysdate, 'DDMMYYYY-HH24:MI:SS');
      end if;
    end if;
    if length(util_random.ru_extract(l_tmp_reference, 3, '~')) != length(l_tmp_reference) then
      -- increment is defined
      generator_definition(column_idx).builtin_increment := util_random.ru_extract(l_tmp_reference, 3, '~');
    else
      if generator_definition(column_idx).builtin_type = 'numiterate' then
        generator_definition(column_idx).builtin_increment := '1¤5';
      elsif generator_definition(column_idx).builtin_type = 'datiterate' then
        generator_definition(column_idx).builtin_increment := 'minutes¤1¤5';
      end if;
    end if;
    -- First build the define code.
    if generator_definition(column_idx).builtin_type = 'numiterate' then
      generator_definition(column_idx).builtin_define_code := '
        l_bltin_' || generator_definition(column_idx).column_name || ' number := ' || generator_definition(column_idx).builtin_startpoint || ';';
    elsif generator_definition(column_idx).builtin_type = 'datiterate' then
      generator_definition(column_idx).builtin_define_code := '
        l_bltin_' || generator_definition(column_idx).column_name || ' date := to_date(''' || generator_definition(column_idx).builtin_startpoint || ''', ''DDMMYYYY-HH24:MI:SS'');';
    end if;
    -- Now we can build the logic.
    if generator_definition(column_idx).builtin_type = 'numiterate' then
      generator_definition(column_idx).builtin_logic_code := '
        l_bltin_' || generator_definition(column_idx).column_name || ' := ' || generator_definition(column_idx).builtin_function || '(l_bltin_' || generator_definition(column_idx).column_name || ', ' || util_random.ru_extract(generator_definition(column_idx).builtin_increment, 1, '¤') || ', ' || util_random.ru_extract(generator_definition(column_idx).builtin_increment, 2, '¤') || ');';
    elsif generator_definition(column_idx).builtin_type = 'datiterate' then
      generator_definition(column_idx).builtin_logic_code := '
        l_bltin_' || generator_definition(column_idx).column_name || ' := ' || generator_definition(column_idx).builtin_function || '(l_bltin_' || generator_definition(column_idx).column_name || ', ''' || util_random.ru_extract(generator_definition(column_idx).builtin_increment, 1, '¤') || ''', ' || util_random.ru_extract(generator_definition(column_idx).builtin_increment, 2, '¤') || ', ' || util_random.ru_extract(generator_definition(column_idx).builtin_increment, 3, '¤') || ');';
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end parse_builtin;

  procedure parse_fixed (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  )

  as

    l_classic_field_def       varchar2(4000);

  begin

    dbms_application_info.set_action('parse_fixed');

    if length(field_spec) < 4000 then
      l_classic_field_def := to_char(field_spec);
    end if;

    generator_definition(column_idx).column_type := 'fixed';
    generator_definition(column_idx).fixed_value := substr(util_random.ru_extract(l_classic_field_def, 3, '#'), 2);

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end parse_fixed;

  procedure parse_reference (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  )

  as

    l_classic_field_def       varchar2(4000);
    l_tmp_reference           varchar2(4000);

  begin

    dbms_application_info.set_action('parse_reference');

    if length(field_spec) < 4000 then
      l_classic_field_def := to_char(field_spec);
    end if;

    -- This is a reference field.
    generator_definition(column_idx).column_type := 'reference field';
    l_tmp_reference := util_random.ru_extract(l_classic_field_def, 3, '#');
    generator_definition(column_idx).reference_table := substr(util_random.ru_extract(l_tmp_reference, 1, '¤'), 2);
    generator_definition(column_idx).reference_column := util_random.ru_extract(l_tmp_reference, 2, '¤');
    generator_definition(column_idx).ref_dist_type := util_random.ru_extract(l_tmp_reference, 3, '¤');
    if length(util_random.ru_extract(l_tmp_reference, 4, '¤')) != length(l_tmp_reference) then
      generator_definition(column_idx).ref_dist_default := util_random.ru_extract(l_tmp_reference, 4, '¤');
    else
      if generator_definition(column_idx).ref_dist_type = 'simple' then
        generator_definition(column_idx).ref_dist_default := '1';
      elsif generator_definition(column_idx).ref_dist_type = 'range' then
        generator_definition(column_idx).ref_dist_default := '1,5';
      elsif generator_definition(column_idx).ref_dist_type = 'weighted' then
        generator_definition(column_idx).ref_dist_default := '2~0.5^4~0.5';
      end if;
    end if;
    -- Build the definition code for the reference field.
    generator_definition(column_idx).ref_define_code := '
      type t_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_c_tab is table of number index by varchar2(4000);
      l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list t_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_c_tab;
      l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx varchar2(4000);';

    if generator_definition(column_idx).ref_dist_type = 'simple' then
      generator_definition(column_idx).ref_define_code := generator_definition(column_idx).ref_define_code ||'
        l_ref_distr_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' number := round(generator_count/dist_' || substr(generator_definition(column_idx).column_name, 1, 15) ||');';
    elsif generator_definition(column_idx).ref_dist_type in ('range', 'weighted') then
      generator_definition(column_idx).ref_define_code := generator_definition(column_idx).ref_define_code ||'
        l_ref_distr_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' number := generator_count;
        l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' number := 0;
        l_ref_min_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' number := substr(dist_'|| substr(generator_definition(column_idx).column_name, 1, 15) ||', 1, instr(dist_'|| substr(generator_definition(column_idx).column_name, 1, 15) ||', '','') - 1);
        l_ref_max_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' number := substr(dist_'|| substr(generator_definition(column_idx).column_name, 1, 15) ||', instr(dist_'|| substr(generator_definition(column_idx).column_name, 1, 15) ||', '','') + 1);';
    end if;
    generator_definition(column_idx).ref_define_code := generator_definition(column_idx).ref_define_code ||'
      cursor c_ref_'|| substr(generator_definition(column_idx).reference_column, 1, 15) ||'(dist_in number) is
        select ' || generator_definition(column_idx).reference_column || ' as ref_dist_col
        from (
          select ' || generator_definition(column_idx).reference_column || '
          from ' || generator_definition(column_idx).reference_table || '
          order by dbms_random.value
        )
        where rownum <= dist_in;
    ';
    -- Now we build the loading of the reference data code.
    generator_definition(column_idx).ref_loader_code := '
      -- Load reference data cursors to lists
      for i in c_ref_'|| substr(generator_definition(column_idx).reference_column, 1, 15) ||'(l_ref_distr_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ') loop';
    if generator_definition(column_idx).ref_dist_type = 'simple' then
      generator_definition(column_idx).ref_loader_code := generator_definition(column_idx).ref_loader_code || '
        l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list(i.ref_dist_col) := dist_'|| substr(generator_definition(column_idx).column_name, 1, 15) ||';
      ';
    elsif generator_definition(column_idx).ref_dist_type in ('range', 'weighted') then
      -- For range we do a r_natural based on input. Always keeping track of total
      -- count so we only generate the required rows in the child table.
      generator_definition(column_idx).ref_loader_code := generator_definition(column_idx).ref_loader_code || '
        l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list(i.ref_dist_col) := core_random.r_natural(l_ref_min_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ', l_ref_max_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ');
        l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' := l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' + l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list(i.ref_dist_col);
        if l_ref_min_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' > l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' then
          l_ref_min_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' := 1;
          l_ref_max_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' := l_ref_min_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ';
        elsif l_ref_max_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' > l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' then
          l_ref_max_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' := l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ';
        end if;
        if l_ref_track_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' >= l_ref_distr_' || substr(generator_definition(column_idx).reference_column, 1, 15) || ' then
          exit;
        end if;';
    end if;
    generator_definition(column_idx).ref_loader_code := generator_definition(column_idx).ref_loader_code || '
      end loop;
      -- Set the index
      l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx := l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list.first;
    ';
    -- Now we build the logic of reference values
    generator_definition(column_idx).ref_logic_code := '
        generator_definition.' || generator_definition(column_idx).column_name || ' := l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx;
        l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list(l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx) := l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list(l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx) - 1;
        if l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list(l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx) = 0 then
          l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx := l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list.next(l_'|| substr(generator_definition(column_idx).reference_column, 1, 15) || '_list_idx);
        end if;
    ';

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end parse_reference;

  procedure parse_referencelist (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
  )

  as

    l_classic_field_def       varchar2(4000);

  begin

    dbms_application_info.set_action('parse_referencelist');

    if length(field_spec) < 4000 then
      l_classic_field_def := to_char(field_spec);
    end if;

    generator_definition(column_idx).column_type := 'referencelist';
    if substr(util_random.ru_extract(l_classic_field_def, 3, '#'), 2, 1) = '[' then
      -- Fixed list. Set referencelist values to string between the square brackets.
      generator_definition(column_idx).fixed_value := substr(util_random.ru_extract(l_classic_field_def, 3, '#'), 3);
      generator_definition(column_idx).fixed_value := substr(generator_definition(column_idx).fixed_value, 1, length(generator_definition(column_idx).fixed_value) - 1);
    else
      -- Generate the list at runtime. Define the code to do so.
      null;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end parse_referencelist;

  procedure parse_generated (
    field_spec                in                    clob
    , column_idx              in                    number
    , generator_definition    in out nocopy         testdata_ninja.generator_columns
    , input_tracker           in out nocopy         testdata_ninja.track_input_tab2
    , input_idx               in                    number
  )

  as

    l_classic_field_def       varchar2(4000);
    l_tmp_reference           varchar2(4000);
    l_reference_replace       varchar2(4000);

  begin

    dbms_application_info.set_action('parse_generated');

    if length(field_spec) < 4000 then
      l_classic_field_def := to_char(field_spec);
    end if;

    generator_definition(column_idx).column_type := 'generated';
    -- First check if we allow nulls. If the generator is surrounded by parentheses
    -- then we allow nulls. The number after the closing parentheses is the percentage
    -- of rows that should be null.
    l_tmp_reference := util_random.ru_extract(l_classic_field_def, 3, '#');
    if substr(l_tmp_reference, 1, 1) = '(' then
      -- Column allowed to be null.
      -- check if nullable percentage is set, else default to 10%
      if substr(l_tmp_reference, -1, 1) = ')' then
        -- No nullable defined.
        generator_definition(column_idx).generator_nullable := 10;
      else
        generator_definition(column_idx).generator_nullable := substr(l_tmp_reference, instr(l_tmp_reference, ')') + 1);
      end if;
      generator_definition(column_idx).generator := substr(l_tmp_reference, 2, instr(l_tmp_reference, ')') - 2);
    else
      generator_definition(column_idx).generator := l_tmp_reference;
      generator_definition(column_idx).generator_nullable := null;
    end if;
    if length(util_random.ru_extract(l_classic_field_def, 4, '#')) != length(l_classic_field_def) then
      -- Manually specified input variables always override auto replace.
      generator_definition(column_idx).generator_args := util_random.ru_extract(l_classic_field_def, 4, '#');
      l_reference_replace := instr(generator_definition(column_idx).generator_args, '%%');
      while l_reference_replace > 0 loop
        -- Start replacing backwards reference fields
        generator_definition(column_idx).generator_args := substr(generator_definition(column_idx).generator_args, 1, l_reference_replace -1) || 'l_ret_var.' || substr(generator_definition(column_idx).generator_args, l_reference_replace + 2);
        -- Remove end reference field marker
        l_reference_replace := instr(generator_definition(column_idx).generator_args, '%%');
        generator_definition(column_idx).generator_args := substr(generator_definition(column_idx).generator_args, 1, l_reference_replace -1) || substr(generator_definition(column_idx).generator_args, l_reference_replace + 2);
        -- Get the next marker.
        l_reference_replace := instr(generator_definition(column_idx).generator_args, '%%');
      end loop;
    else
      -- Let us check if any of the inputs to this column is generated from other columns.
      for y in 1..input_tracker(input_idx).count loop
        if length(generator_definition(column_idx).generator_args) > 0 then
          generator_definition(column_idx).generator_args := generator_definition(column_idx).generator_args || ', ';
        end if;
        generator_definition(column_idx).generator_args := generator_definition(column_idx).generator_args || input_tracker(input_idx)(y).input_name || ' => ' || 'l_ret_var.' || input_tracker(input_idx)(y).draw_from_col;
      end loop;
    end if;

    dbms_application_info.set_action(null);

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end parse_generated;

begin

  dbms_application_info.set_client_info('testdata_piecebuilder');
  dbms_session.set_identifier('testdata_piecebuilder');

end testdata_piecebuilder;
/
