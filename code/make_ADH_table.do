

set matsize 2000


/*** AKM ADH Data **/
insheet using "../data/ADHdata_AKM.csv", clear
gen year = 1990 + (t2=="TRUE")*10
drop t2

/*** BHJ SHARES **/
merge 1:m czone year using ../data/Lshares.dta, gen(merge_shares)
/*** BHJ SHOCKS **/
merge m:1 sic87dd year using "../data/shocks.dta", gen(merge_shocks)

rename ind_share share_emp_ind_bhj_
gen z_ = share_emp_ind_bhj_ * g
rename g g_
drop g_emp_ind-g_importsUSA
reshape wide share_emp_ind_bhj_ g z_, i(czone year) j(sic87dd)
egen z = rowtotal(z_*)


local controls reg_* l_sh_popedu_c l_sh_popfborn l_sh_empl_f l_sh_routine33 l_task_outsource l_shind_manuf_cbp
local weight weight

local y d_sh_empl_mfg 
local x shock
local z z


local ind_stub share_emp_ind_bhj_
local growth_stub g_

local time_var year
local cluster_var czone

levelsof `time_var', local(years)

/** g_2141 and g_3761 = 0 for all years **/
drop g_2141 `ind_stub'2141
drop g_3761 `ind_stub'3761

forvalues t = 1990(10)2000 {
	foreach var of varlist `ind_stub'* {
		gen t`t'_`var' = (year == `t') * `var'
		}
	foreach var of varlist `growth_stub'* {
		gen t`t'_`var'b = `var' if year == `t'
		egen t`t'_`var' = max(t`t'_`var'b), by(czone)
		drop t`t'_`var'b
		}
	}

tab division, gen(reg_)
drop reg_1
tab year, gen(t)
drop t1

drop if czone == .

set matsize 4000
global controls `controls'
global y `y'
global x `x'
global z `z'
global ind_stub `ind_stub'
global growth_stub `growth_stub'
global weight `weight'
tsset, clear

capture program drop test_and_compare
program define test_and_compare, rclass
	btsls, z($z) x($x) y($y) controls(reg_* t2) ktype("tsls") weight_var($weight)
	local b_bar_2sls_1 = r(beta)
	return scalar b_bar_2sls_1 = `b_bar_2sls_1'
	btsls, z($z) x($x) y($y) controls($controls t2) ktype("tsls") weight_var($weight)
	local b_bar_2sls_2 = r(beta)
	return scalar b_bar_2sls_2 = `b_bar_2sls_2'
	return scalar diff_bar_2sls = `b_bar_2sls_1' - `b_bar_2sls_2'
	btsls, z("`1'") x($x) y($y) controls(reg_* t2) ktype("tsls") weight_var($weight)
	local b_sh_2sls_1 = r(beta)
	return scalar b_sh_2sls_1 = `b_sh_2sls_1'
	btsls, z("`1'") x($x) y($y) controls($controls t2) ktype("tsls") weight_var($weight)
	local b_sh_2sls_2 = r(beta)
	return scalar b_sh_2sls_2 = `b_sh_2sls_2'
	return scalar diff_sh_2sls = `b_sh_2sls_1' - `b_sh_2sls_2'
	btsls, z("`1'") x($x) y($y) controls(reg_* t2) ktype("mbtsls") weight_var($weight)
	local b_sh_mbtsls_1 = r(beta)
	return scalar b_sh_mbtsls_1 = `b_sh_mbtsls_1'
	btsls, z("`1'") x($x) y($y) controls($controls t2) ktype("mbtsls") weight_var($weight)
	local b_sh_mbtsls_2 = r(beta)
	return scalar b_sh_mbtsls_2 = `b_sh_mbtsls_2'
	return scalar diff_sh_mbtsls = `b_sh_mbtsls_1' - `b_sh_mbtsls_2'
end


capture program drop test_and_compare_chao
program define test_and_compare_chao, rclass
	overid_chao, z("`1'") x($x) y($y) controls(reg_* t2)  weight_var($weight)
	local b_1 = r(delta)
	return scalar b_1 = `b_1'
	overid_chao, z("`1'") x($x) y($y) controls($controls t2)  weight_var($weight)
	local b_2 = r(delta)
	return scalar b_2 = `b_2'
	return scalar diff = `b_1' - `b_2'
end

local n = 200

estimates clear
qui reg `y' `x' reg_* i.t2 [aweight=`weight'], cluster(czone)
local b1_ols = string(_b[`x'], "%12.2f")
local se1_ols = "(" + string(_se[`x'], "%12.2f") + ")"
qui reg `y' `x' reg_* i.t2 [aweight=`weight']
estimates store ols1

qui reg `y' `x' `controls' i.t2 [aweight=`weight'], cluster(czone)
local b2_ols = string(_b[`x'], "%12.2f")
local se2_ols = "(" +  string(_se[`x'], "%12.2f") + ")"
qui reg `y' `x' `controls' i.t2 [aweight=`weight']
estimates store ols2

suest ols1 ols2, cluster(czone)
test [ols1_mean]`x'=[ols2_mean]`x'
local p_ols = "[" + string(r(p), "%12.2f") + "]"

ivregress 2sls  `y'  `controls' i.t2  (`x'= t1990_`ind_stub'* t2000_`ind_stub'*  )  [aweight=`weight'], vce(robust)
local insts = e(insts)
local cont = e(exogr)
local insts2 ""
/*** Consruct varlist of independent regressors **/
foreach var in `insts' {
	if ~regexm("`cont'", "`var'") & ~regexm("`var'", "o.") & "t1990_share_emp_ind_bhj_3821" != "`var'" {
		local insts2 "`insts2' `var'"
		}
	else {
		disp "`var'"
		}
	}
estat overid, forceweights
local J_2sls = string(r(score), "%12.2f")
local Jp_2sls = "[" + string(r(p_score), "%12.2f") + "]"


test_and_compare "`insts2'"
local b1_bartik = string(r(b_bar_2sls_1), "%12.2f")
local b2_bartik = string(r(b_bar_2sls_2), "%12.2f")
local b1_2sls = string(r(b_sh_2sls_1), "%12.2f")
local b2_2sls = string(r(b_sh_2sls_2), "%12.2f")
local b1_mbtsls = string(r(b_sh_mbtsls_1), "%12.2f")
local b2_mbtsls = string(r(b_sh_mbtsls_2), "%12.2f")


bootstrap b1_bartika = r(b_bar_2sls_1) b2_bartika = r(b_bar_2sls_2) diff_bartik = r(diff_bar_2sls) ///
  b1_2slsa = r(b_sh_2sls_1) b2_2slsa = r(b_sh_2sls_2) diff_2slsa = r(diff_sh_2sls) ///
  b1_mbtslsa = r(b_sh_mbtsls_1)   b2_mbtslsa = r(b_sh_mbtsls_2) diff_mbtslsa = r(diff_sh_mbtsls), ///  
  cluster(czone) reps(`n'): test_and_compare  "`insts2'"
mat pval = r(table)
local se1_bartik = "[" + string(pval[2,1], "%12.2f") + "]"
local se2_bartik = "[" + string(pval[2,2], "%12.2f") + "]"
local p_bartik = "[" + string(pval[4,3], "%12.2f") + "]"
local se1_2sls = "[" + string(pval[2,4], "%12.2f") + "]"
local se2_2sls = "[" + string(pval[2,5], "%12.2f") + "]"
local p_2sls = "[" + string(pval[4,6], "%12.2f") + "]"
local se1_mbtsls = "[" + string(pval[2,7], "%12.2f") + "]"
local se2_mbtsls = "[" + string(pval[2,8], "%12.2f") + "]"
local p_mbtsls = "[" + string(pval[4,9], "%12.2f") + "]"


qui ivregress liml `y'  (`x' =  `insts2') reg_* t2 [aw=`weight'], cluster(czone)
local b1_liml = string(_b[`x'], "%12.2f")
local se1_liml = "(" + string(_se[`x'], "%12.2f") + ")"
qui ivregress liml `y'  (`x' =  `insts2') `controls' t2 [aw=`weight'], cluster(czone)
local b2_liml = string(_b[`x'], "%12.2f")
local se2_liml = "(" + string(_se[`x'], "%12.2f") + ")"
local N = e(N)
local K = wordcount(e(insts)) - wordcount(e(exogr))
local L = wordcount(e(exogr))
local kappa = e(kappa) - 1
local J_liml  = (`N' - `K' - `L') * (`kappa' - 1)
local alpha_L =  `L' / `N'
local alpha_K =  `K' / `N'
local crit = normal(sqrt((1 - `alpha_L') / ( 1- `alpha_K' - `alpha_L'))*invnorm(0.95)) 
disp chi2(`J_liml', `K'-1)
local Jp_liml = "[" + string(`=chi2(`J_liml', `K'-1)', "%12.2f") + "]"

preserve
local controls2 l_sh_popedu_c l_sh_popfborn l_sh_empl_f l_sh_routine33 l_task_outsource l_shind_manuf_cbp
expand 2, gen(control_ind)

ivregress liml `y'  (control_ind#c.`x' =  control_ind#c.(`insts2')) c.control_ind#c.(`controls2') control_ind#i.(reg_* t2) control_ind [aw=`weight'], cluster(czone)
test  0.control_ind#c.`x' =  1.control_ind#c.`x'
local p_liml = "[" + string(r(p), "%12.2f") + "]"
restore

capture bootstrap b1_hful = r(b_1) b2_hful = r(b_2) diff_hful = r(diff), cluster(czone) reps(`n'): test_and_compare_chao "`insts2'"
mat b = e(b)
mat V = vecdiag(e(V))
local b1_hful = string(b[1,1], "%12.2f")
local b2_hful = string(b[1,2], "%12.2f")
local se1_hful = "(" + string(sqrt(V[1,1]), "%12.2f") + ")"
local se2_hful = "(" + string(sqrt(V[1,2]), "%12.2f") + ")"
mat pval = r(table)
local p_hful = "[" + string(pval[4,3], "%12.2f") + "]"

capture overid_chao, z("`insts2'") x($x) y($y) controls($controls t2)  weight_var($weight)
local J_hful = string(r(T), "%12.2f")
local Jp_hful = "[" + string(r(p), "%12.2f") + "]"

capture file close fh
capture erase "../results/adh_results.tex"
file open fh using "../results/adh_results.tex", write replace

file write fh "OLS & `b1_ols' & `b2_ols' & `p_ols' & \\" _n
file write fh "    & `se1_ols'& `se2_ols'&         & \\" _n
file write fh "2SLS (Bartik) & `b1_bartik' & `b2_bartik' & `p_bartik' & \\" _n
file write fh "    & `se1_bartik' & `se2_bartik' &         & \\" _n
file write fh "2SLS & `b1_2sls' & `b2_2sls' & `p_2sls' & `J_2sls' \\" _n
file write fh "    & `se1_2sls'& `se2_2sls'&         & `Jp_2sls' \\" _n
file write fh "MBTSLS & `b1_mbtsls' & `b2_mbtsls' & `p_mbtsls' & \\" _n
file write fh "    & `se1_mbtsls'& `se2_mbtsls'&         & \\" _n
file write fh "LIML & `b1_liml' & `b2_liml' & `p_liml' & `J_liml'\\" _n
file write fh "    & `se1_liml'& `se2_liml'&         & `Jp_liml' \\" _n
file write fh "HFUL & `b1_hful' & `b2_hful' & `p_hful' & `J_hful' \\" _n
file write fh "    & `se1_hful'& `se2_hful'&         &  `Jp_hful' \\" _n

file close fh
