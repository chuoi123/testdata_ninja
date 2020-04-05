create or replace package body topological_ninja

as

  function value_or_key_in_dep_list (
    p_value_in              varchar2
    , p_dependency_list     topo_dependency_list
  )
  return boolean

  as

    l_ret_var               boolean := false;
    l_key_idx               varchar2(4000);

  begin

    dbms_application_info.set_action('value_in_dependency_list');

    l_key_idx := p_dependency_list.first;
    while l_key_idx is not null loop
      if p_dependency_list(l_key_idx) = p_value_in then
        l_ret_var := true;
      end if;
      if l_key_idx = p_value_in then
        l_ret_var := true;
      end if;
      l_key_idx := p_dependency_list.next(l_key_idx);
    end loop;

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end value_or_key_in_dep_list;

  function value_in_dependency_list (
    p_value_in              varchar2
    , p_dependency_list     topo_dependency_list
  )
  return boolean

  as

    l_ret_var               boolean := false;
    l_key_idx               varchar2(4000);

  begin

    dbms_application_info.set_action('value_in_dependency_list');

    l_key_idx := p_dependency_list.first;
    while l_key_idx is not null loop
      if p_dependency_list(l_key_idx) = p_value_in then
        l_ret_var := true;
      end if;
      l_key_idx := p_dependency_list.next(l_key_idx);
    end loop;

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end value_in_dependency_list;

  function value_already_ordered (
    p_value_in              varchar2
    , p_ordered_list_num    topo_number_list default null
    , p_ordered_list_char   topo_char_list default null
  )
  return boolean

  as

    l_ret_var               boolean := false;
    l_list_idx              number;

  begin

    dbms_application_info.set_action('value_already_ordered');

    if p_ordered_list_num is not null then
      l_list_idx := p_ordered_list_num.first;
      while l_list_idx is not null loop
        if p_ordered_list_num(l_list_idx) = p_value_in then
          l_ret_var := true;
        end if;
        l_list_idx := p_ordered_list_num.next(l_list_idx);
      end loop;
    elsif p_ordered_list_char is not null then
      l_list_idx := p_ordered_list_char.first;
      while l_list_idx is not null loop
        if p_ordered_list_char(l_list_idx) = p_value_in then
          l_ret_var := true;
        end if;
        l_list_idx := p_ordered_list_char.next(l_list_idx);
      end loop;
    end if;

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end value_already_ordered;

  function dependency_key_from_val (
    p_value_in              varchar2
    , p_dependency_list     topo_dependency_list
  )
  return varchar2

  as

    l_ret_var               varchar2(4000) := null;
    l_key_idx               varchar2(4000);


  begin

    dbms_application_info.set_action('dependency_key_from_val');

    l_key_idx := p_dependency_list.first;
    while l_key_idx is not null loop
      if p_dependency_list(l_key_idx) = p_value_in then
        l_ret_var := l_key_idx;
      end if;
      l_key_idx := p_dependency_list.next(l_key_idx);
    end loop;

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end dependency_key_from_val;

  function f_s (
    dependency_list         topo_dependency_list
    , full_list_num         topo_number_list default null
    , full_list_char        topo_char_list default null
  )
  return topo_number_list

  as

    l_ret_var               topo_number_list := topo_number_list();
    l_input_list_key        varchar2(4000);
    l_checked_dependent     varchar2(4000);
    l_dependent             varchar2(4000);
    l_visited_list          topo_dependency_list;

  begin

    dbms_application_info.set_action('f_s');

    -- Begin by putting the numbers without dependency
    if full_list_num is not null then
      for i in 1..full_list_num.count loop
        if not value_or_key_in_dep_list(full_list_num(i),dependency_list) then
          l_ret_var.extend(1);
          l_ret_var(l_ret_var.count) := full_list_num(i);
        end if;
      end loop;
    end if;

    -- Start the intial loop of dependency list for chaining every member of dependency list.
    l_input_list_key := dependency_list.first;
    while l_input_list_key is not null loop
      l_checked_dependent := dependency_list(l_input_list_key);

      -- Now we can start the inner loop to find last chain in the graph.
      l_dependent := dependency_list.first;
      while l_dependent is not null loop

        if l_dependent = dependency_list(l_input_list_key) then
          if not value_in_dependency_list(l_dependent, l_visited_list) then
            l_visited_list(l_input_list_key) := dependency_list(l_dependent);
          end if;
        end if;

        l_dependent := dependency_list.next(l_dependent);
      end loop;

      if not l_visited_list.exists(l_input_list_key) then
        l_visited_list(l_input_list_key) := dependency_list(l_input_list_key);
      end if;

      l_input_list_key := dependency_list.next(l_input_list_key);
    end loop;

    -- l_ret_var := topo_number_list();

    -- Now we move into the sorting and ordering step.
    -- Main loop over visited list from first step.
    l_input_list_key := l_visited_list.first;
    while l_input_list_key is not null loop

      -- First check if dependant is already added to final list
      if not value_already_ordered(p_value_in => l_visited_list(l_input_list_key), p_ordered_list_num => l_ret_var) then
        -- Check if the value is dependant on any other number in the list.
        -- If not we can add it to the order list.
        if not l_visited_list.exists(l_visited_list(l_input_list_key)) then
          -- The last of the chain is not itself dependant on others. We can build add it to final order.
          l_ret_var.extend(1);
          l_ret_var(l_ret_var.count) := l_visited_list(l_input_list_key);
        else
          -- Check if that value has already been built. If yes we can add it.
          -- If not we need to check second level dependency.
          if value_already_ordered(p_value_in => l_visited_list(l_visited_list(l_input_list_key)), p_ordered_list_num => l_ret_var) then
            l_ret_var.extend(1);
            l_ret_var(l_ret_var.count) := l_visited_list(l_input_list_key);
          end if;
        end if;
      end if;

      l_input_list_key := l_visited_list.next(l_input_list_key);
    end loop;

    -- Second part of final list combining other part of the two lists.
    -- This part will add the first column numbers to the final list.
    l_input_list_key := l_visited_list.first;
    while l_input_list_key is not null loop
      if not value_in_dependency_list(l_input_list_key, dependency_list) then
        l_ret_var.extend(1);
        l_ret_var(l_ret_var.count) := l_input_list_key;
      else
        -- Just check if last chain is added already for the key value in input list.
        if value_already_ordered(p_value_in => l_visited_list(dependency_key_from_val(l_input_list_key, dependency_list)), p_ordered_list_num => l_ret_var) then
          if not value_already_ordered(p_value_in => l_input_list_key, p_ordered_list_num => l_ret_var) then
            l_ret_var.extend(1);
            l_ret_var(l_ret_var.count) := l_input_list_key;
          end if;
        end if;
      end if;

      l_input_list_key := l_visited_list.next(l_input_list_key);
    end loop;

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end f_s;

  function f_s_num (
    dependency_list         topo_dependency_list
    , full_list_num         topo_number_list
  )
  return topo_number_list

  as

    l_ret_var               topo_number_list;

  begin

    dbms_application_info.set_action('f_s_num');

    dbms_application_info.set_action(null);

    return l_ret_var;

    exception
      when others then
        dbms_application_info.set_action(null);
        raise;

  end f_s_num;

begin

  dbms_application_info.set_client_info('topological_ninja');
  dbms_session.set_identifier('topological_ninja');

end topological_ninja;
/
