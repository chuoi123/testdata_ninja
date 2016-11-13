create or replace package body demograhics_data

as

begin

  -- US Demographics
  c_d_arr('US').p_0_14 := 19.4;
  c_d_arr('US').p_15_64 := 66.2;
  c_d_arr('US').p_65_ := 14.4;
  c_d_arr('US').p_avg_age := 80;
  c_d_arr('US').p_avg_age_f := 82;
  c_d_arr('US').p_avg_age_m := 77;
  c_d_arr('US').p_0_14_mf := 1.04;
  c_d_arr('US').p_15_64_mf := 1;
  c_d_arr('US').p_65_mf := 0.75;
  c_d_arr('US').population := 322479000;

  -- China CN Demographics
  c_d_arr('CN').p_0_14 := 17.2;
  c_d_arr('CN').p_15_64 := 73.4;
  c_d_arr('CN').p_65_ := 9.4;
  c_d_arr('CN').p_avg_age := 75.35;
  c_d_arr('CN').p_avg_age_f := 76.68;
  c_d_arr('CN').p_avg_age_m := 74.09;
  c_d_arr('CN').p_0_14_mf := 1.13;
  c_d_arr('CN').p_15_64_mf := 1.06;
  c_d_arr('CN').p_65_mf := 0.91;
  c_d_arr('CN').population := 1357000000;

  -- India IN Demographics
  c_d_arr('IN').p_0_14 := 31.2;
  c_d_arr('IN').p_15_64 := 63.6;
  c_d_arr('IN').p_65_ := 5.3;
  c_d_arr('IN').p_avg_age := 68.89;
  c_d_arr('IN').p_avg_age_f := 72.61;
  c_d_arr('IN').p_avg_age_m := 67.46;
  c_d_arr('IN').p_0_14_mf := 1.10;
  c_d_arr('IN').p_15_64_mf := 1.06;
  c_d_arr('IN').p_65_mf := 0.9;
  c_d_arr('IN').population := 1336286256;

  -- Denmark DK demograhics
  c_d_arr('DK').p_0_14 := 18.1;
  c_d_arr('DK').p_15_64 := 65.8;
  c_d_arr('DK').p_65_ := 16.1;
  c_d_arr('DK').p_avg_age := 78.3;
  c_d_arr('DK').p_avg_age_f := 80.78;
  c_d_arr('DK').p_avg_age_m := 75.96;
  c_d_arr('DK').p_0_14_mf := 1.06;
  c_d_arr('DK').p_15_64_mf := 1.01;
  c_d_arr('DK').p_65_mf := 0.78;
  c_d_arr('DK').population := 5500510;

  dbms_application_info.set_client_info('demograhics_data');
  dbms_session.set_identifier('demograhics_data');

end demograhics_data;
/
