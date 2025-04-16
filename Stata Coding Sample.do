stop

*Emily Paulin
*This coding sample is a sample of the Stata code for my senior thesis, adapted on April 5, 2025. 

*Change directory to folder with all data files
cd "/Users/emilypaulin/Princeton/Academics/Senior Thesis/Data Replication"

*Set log file
log close
log using 04052025.log

*Installs
ssc install coefplot
ssc install eventdd 
ssc install matsort 
ssc install reghdfe 
ssc install ftool
ssc install estout, replace
ssc install drdid, all replace
ssc install csdid, all replace

********************************************************************************
*Import and Clean Data
********************************************************************************

********************************************************************************
*Dependent Variable
********************************************************************************

*EDGAR carbon emissions import and cleaning

import excel  "IEA_EDGAR_CO2_1970_2023.xlsx", sheet("TOTALS BY COUNTRY") clear

save co2, replace

rename A IPCC_annex
rename B C_group_IM24_sh
rename C Country_code
rename D Name
rename E Substance
rename F-BG x#, addnumber(1970)

save co2, replace

drop in 1/10
destring x1970-x2023, replace
rename Name country
drop Substance
drop IPCC_annex 
save co2, replace

*Co2 database is wide, this needs to be fixed before merge later on
use co2, clear 
reshape long x, i(country) j(year)
rename x emissions 
drop if emissions == .
rename Country_code countrycode
save co2_long, replace

********************************************************************************
*Possible Control Variables
********************************************************************************

*GDP and population data from Penn World Tables
use "maddison2023_web.dta", clear
drop if gdppc == .
drop if pop == .
drop if year <= 1970 //removes historical data going back really far
tab year
save gdp, replace

*Paris Agreement ratification dates
import excel using "Paris Agreement Ratification Year.xlsx", clear
drop D-G
rename A country
rename B countrycode
rename C ratificationyear
drop in 1
destring ratificationyear, replace
replace countrycode = "VAT" if country == "Holy See"
drop if country == "European Union"
save parisratification, replace

*Economist Intelligence Unit Shares of GDP
import delimited using "agriculturepcgdp.csv", clear
rename v6-v49 x#, addnumber(1980)
rename v2 shortcountrycode 
rename v3 country
drop v1 v4 v5 
destring x1980-x2023, replace force
reshape long x, i(country) j(year)
rename x agriculturepcgdp
save agriculturepcgdp, replace

import delimited using "manufacturingpcgdp.csv", clear
rename v6-v49 x#, addnumber(1980)
rename v2 shortcountrycode 
rename v3 country
drop v1 v4 v5 
destring x1980-x2023, replace force
reshape long x, i(country) j(year)
rename x manufacturingpcgdp
save manufacturingpcgdp, replace

use manufacturingpcgdp, clear
merge 1:1 shortcountrycode year using agriculturepcgdp, gen(merge1) //agriculture is missing a lot of data, but the other two are good!
save manufacturingagriculturepcgdp, replace

import delimited using "servicespcgdp.csv", clear
rename v6-v49 x#, addnumber(1980)
rename v2 shortcountrycode 
rename v3 country
drop v1 v4 v5 
destring x1980-x2023, replace force
reshape long x, i(country) j(year)
rename x servicespcgdp
save servicespcgdp, replace

use manufacturingagriculturepcgdp, clear
merge 1:1 shortcountrycode year using servicespcgdp, gen(merge2)
tab merge1
drop merge1 merge2
save gdpshares, replace

*Vdem data
use V-Dem-CY-Full+Others-v14
tab v2x_polyarchy //Electoral democracy (0-1) 26595
tab v2xeg_eqdr //Equal distribution of resources index (0-1) 19368

rename country_text_id countrycode 
rename country_id numericcode
keep countrycode numericcode year v2x_polyarchy v2xeg_eqdr 
drop if year <= 1970
save vdem, replace

*Renewable energy share data
import excel using "Renewable energy share in the total final energy consumption (%) EG_FEC_RNEW.xlsx", clear //percent of renewable energy in final energy consumption
drop A-E H I 
drop AF-AZ //empty observations in all rows
rename F numericcode
rename G country 
rename J-AE x#, addnumber(2000)
drop in 1
destring numericcode, replace
reshape long x, i(country) j(year)
rename x pcrenewable
destring pcrenewable, replace force
save pcrenewable, replace

* Dataset for merging, directly from IBAN website
import delimited "countrycodes.csv", clear
rename v1 country
rename v2 shortcountrycode
rename v3 countrycode
rename v4 numericcode
save countrycodes, replace

********************************************************************************
*Merge*
********************************************************************************

*List of databases for easy reference
use co2, clear
use gdp, clear //this also has population data
use RD_IEA, clear
use co2_long, clear
use WBabsenceofviolence, clear
use WBabsenceofviolence_long, clear
use WBabsenceofviolence_long_renamed, clear
use IMF_mitigationexpenditures, clear
use IMF_mitigationexpenditures_pcGDP, clear
use IMF_environmentalprotectionspending_pcGDP, clear
use IMF_environmentalprotectionRDspending_pcGDP, clear
use gdpshares, clear
use countrycodes, clear
use wbdevindicators_clean, clear

*Merge emissions and country codes
use co2_long, clear
merge m:1 countrycode using countrycodes 
sort _merge 
keep if _merge == 3 //drops only International Aviation, Netherlands Antilles, International Shipping, Serbia and Montenegro from emissions database, plus extras that weren't included in emissions database
sort country year
order country countrycode shortcountrycode numericcode year
drop _merge

save merged, replace

*Merge emissions and country codes with GDP and population data
merge 1:1 countrycode year using gdp, gen(mergea)

*Algorithm below to check if anything at all merged; if nothing, it's not worth keeping. I also checked to ensure that none of the countries that would be omitted were particularly large emitters. 
gen mergecheck = mergea == 3
bysort countrycode: egen merged_count = total(mergecheck)
keep if merged_count > 0
drop mergecheck mergea
drop merged_count
save merged, replace

*Merge in Paris ratification dates
merge m:1 countrycode using parisratification, gen(parismerge)
sort parismerge country year
sort country year //some are missing or incorrect, will fix
replace ratificationyear = 2016 if countrycode == "HKG"

*This will be dropped anyway because of the DID assumption that treatment status doesn't change later
replace ratificationyear = 2016 if countrycode == "USA" & year < 2020 //Not exactly sure if this is the right way to deal with this. "On 4 November 2019, the Government of the United States of America notified the Secretary-General of its decision to withdraw from the Agreement which took effect on 4 November 2020 in accordance with article 28 (1) and (2) of the Agreement."
replace ratificationyear = 2016 if countrycode == "PRI" & year < 2020
replace ratificationyear = 2021 if countrycode == "PRI" & year >= 2020

drop parismerge

*Generate the dummy variable for whether Paris was ratified/date
gen ratified = .
replace ratified = 1 if ratificationyear <= year
replace ratified = 0 if ratified == .
gen time_to_ratification = year - ratificationyear
tab country if emissions == . //Countries dropped for lack of data will need to be included in the appendix.
drop if emissions == .  

*GDP shares
merge 1:1 shortcountrycode year using gdpshares, gen(merge) //data goes back to 1980 only (this is fine)
drop if country == "Geography" //No idea why this exists
drop if countrycode == ""

gen mergecheck = merge == 3
bysort countrycode: egen merged_count = total(mergecheck)
keep if merged_count > 0
drop mergecheck merge merged_count
sort country year
save merged, replace

*Generate log variables
gen loggdp = ln(gdp)
gen logpop = log(pop)
gen gdpsquared = (loggdp)^2
save merged, replace

*Merge in Vdem data
use merged, clear
merge 1:1 countrycode year using vdem, gen(merge)
sort merge countrycode year
drop if merge == 2
sort countrycode year
drop merge
save merged, replace

*Merge in percent renewable energy
use merged, clear
merge 1:1 numericcode year using pcrenewable, gen(merge1) 
sort merge1 country
drop if merge1==2
sort country year
drop merge1
order country countrycode shortcountrycode numericcode year C_group_IM24_sh emissions
save merged, replace

*Label variables so that they will look nice
label var manufacturingpcgdp "Manufacturing Share of GDP"
label var agriculturepcgdp "Agriculture Share of GDP"
label var servicespcgdp "Services Share of GDP"
label var emissions "Emissions (kilotons per year)"
label var gdppc "GDP Per Capita"
label var pop "Population (thousands)"
label var loggdp "Log of GDP"
label var logpop "Log of Population"
label var v2x_polyarchy "Electoral Democracy Index"
label var v2xeg_eqdr "Equal Distribution of Resources Index"
label var gdpsquared "Log GDP Squared"
label var pcrenewable "Renewable Energy Consumption Share (%)"
save data_final, replace

*Databases for each set of countries that will be studied together
use data_final, clear
keep if country == "Taiwan" | country == "South Korea"
save taiwanskcomparison, replace

use data_final, clear
keep if country == "Iran" | country == "Algeria"
save iranalgeria, replace

use data_final, clear
keep if country == "Iran" |country == "Algeria" | country == "Taiwan" | country == "South Korea"
save fourcountries, replace

use data_final, clear
drop if country == "United States" | country == "Puerto Rico" //this is because diff-in-diff assumes no change in treatment status once a unit becomes treated. Both the US and Puerto Rico joined, exited, rejoined, and will be exiting again. 
save withoutUS, replace

use data_final, clear
drop if country == "Taiwan" | country == "South Korea" | country == "Libya" | country == "Yemen" | country == "United States" | country == "Puerto Rico"
save nocontrols, replace //For use with the Callaway and Sant'Anna (2021) differences-in-differences methodology with not-yet-treated units as controls.

********************************************************************************
*Data Analysis*
********************************************************************************

use data_final, clear

*Summary statistics
outreg2 using summarystatistics.tex, replace sum(log) label drop(year numericcode ratificationyear ratified time_to_ratification) title(Table 1: Summary Statistics)

*Graph of emissions rising
use data_final, clear
twoway line emissions year if country == "United States"
twoway line emissions year if country == "Iran"
twoway line emissions year if country == "Algeria"
twoway line emissions year if country == "South Korea"
twoway line emissions year if country == "Taiwan"
twoway line emissions year if country == "China"
twoway line emissions year if country == "France"

twoway (line emissions year if country == "Iran") (line emissions year if country == "United States") (line emissions year if country == "China") (line emissions year if country == "India") (line emissions year if country == "Germany"), legend(label(1 "Iran") label(2 "United States") label(3 "China") label(4 "India") label(5 "Germany")) ytitle("Carbon Dioxide Emissions (kton)") xtitle("Year") title("Emissions over Time")

*Iran and Algeria
use iranalgeria, clear

eventdd emissions loggdp logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) graph_op(ytitle("Carbon Dioxide Emissions (kton)")) accum //iranalgeria1
outreg2 using iranalgeria.tex, replace label title(Table 2: Iran and Algeria)

eventdd emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum  graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //reverses relationship, iranalgeria2
outreg2 using iranalgeria.tex, append label 

eventdd emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr pcrenewable if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //iranalgeria3
outreg2 using iranalgeria.tex, append label

*Taiwan and South Korea
use taiwanskcomparison, clear
eventdd emissions loggdp logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //no parallel trends, taiwansk1
outreg2 using taiwansk.tex, replace label title(Table 3: Taiwan and South Korea)

eventdd emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //not even close to parallel trends, taiwansk2
outreg2 using taiwansk.tex, append label 

eventdd emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //taiwansk3, parallel trends before and weirdness after
outreg2 using taiwansk.tex, append label 

*Robustness checks
use fourcountries, clear
eventdd emissions loggdp logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //fourcountries1.jpg
outreg2 using fourcountries.tex, replace label title(Table 4: All Four Countries)

eventdd emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum  graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //fourcountries2.jpg
outreg2 using fourcountries.tex, append label

eventdd emissions loggdp logpop agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //fourcountries3.jpg
outreg2 using fourcountries.tex, append label

*With Libya and Yemen
use smallregression, clear
eventdd emissions loggdp logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum 

*All countries together
use withoutUS, clear
eventdd emissions loggdp logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) graph_op(ytitle("Carbon Dioxide Emissions (kton)")) accum //fullregression1.jpg
outreg2 using fullregression.tex, replace label title(Table 5: Full Regression)

eventdd emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //fullregression2.jpg
outreg2 using fullregression.tex, append label 

eventdd emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr pcrenewable if year>=2000, hdfe absorb(country) timevar(time_to_ratification) leads(16) lags(6) accum graph_op(ytitle("Carbon Dioxide Emissions (kton)")) //fullregression3.jpg
outreg2 using fullregression.tex, append label 

*Make ratification year table
tab country if ratificationyear == 2016
tab country if ratificationyear == 2017
tab country if ratificationyear == 2018
tab country if ratificationyear == 2019
tab country if ratificationyear == 2020
tab country if ratificationyear == 2021

*Callaway Sant'Anna Part
ssc install drdid, all replace
ssc install csdid, all replace

use nocontrols, clear
csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet //3166, jump positive and then negative

csdid_plot, group(2016) //nocontrols2016_1.jpg
csdid_plot, group(2017) //nocontrols2017_1.jpg

outreg2 using nocontrols.tex

csdid emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr if year >= 2000, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) //

csdid_plot, group(2016) //nocontrols2016_2.jpg
csdid_plot, group(2017) //nocontrols2017_2.jpg

csdid emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr pcrenewable if year >= 2000, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) //

use data_final, clear

csdid emissions loggdp logpop agriculturepcgdp servicespcgdp if year>=2000, ivar(numericcode) time(year) gvar(ratificationyear) 
estat all
estat pretrend
estat simple

outreg2 using test1.tex, replace label

*By analysis group: developing developed eit ldc
use data_final3, clear //Reminder that developed=1, eit=2, developing=3, ldc separate variable

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000 & developmentstatus == 1, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //developed2016.jpg

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000 & developmentstatus == 3, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //developing2016.jpg
csdid_plot, group(2017)	//developing2017.jpg
//2018 results all over the place

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000 & ldcstatus == 1, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //nothing worth keeping from this

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr if year >= 2000 & developmentstatus == 1, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet //no results for developed countries with all controls.

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr pcrenewable if year >= 2000 & developmentstatus == 3, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //developing2016_1.jpg
csdid_plot, group(2017) //developing2017_1.jpg



