stop

* Emily Paulin

*Change directory to folder with all data files
cd "/Users/emilypaulin/Princeton/Academics/Senior Thesis/Data"

*Set log file
log close
log using 04092025.log

********************************************************************************
*Data Analysis
********************************************************************************

*Let's make another dataset for each pair of countries
use data_final, clear
keep if country == "Taiwan" | country == "South Korea"
save taiwanskcomparison, replace

use data_final, clear
keep if country == "Iran" | country == "Algeria"
save iranalgeria, replace

use data_final, clear
keep if country == "Iran" | country == "Indonesia"
save iranindonesia, replace

use data_final, clear
keep if country == "Iran" |country == "Algeria" | country == "Taiwan" | country == "South Korea"
save fourcountries, replace

use data_final, clear
keep if country == "Iran" |country == "Algeria" | country == "Taiwan" | country == "South Korea" | country == "Libya" | country == "Yemen"
save smallregression, replace

use data_final, clear
drop if country == "United States" | country == "Puerto Rico"
save withoutUS, replace

use data_final, clear
country == "Libya" | country == "Yemen"
save smallregression, replace

use data_final, clear
drop if country == "Taiwan" | country == "South Korea" | country == "Libya" | country == "Yemen" | country == "United States" | country == "Puerto Rico"
save nocontrols, replace

********************************************************************************
*Data analysis*
********************************************************************************

use data_final, clear

*Summary statistics
outreg2 using summarystatistics.tex, replace sum(log) label drop(year numericcode ratificationyear ratified time_to_ratification) title(Table 1: Summary Statistics)

*Graphs
twoway scatter emissions year

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

*Make ratification year table
tab country if ratificationyear == 2016
tab country if ratificationyear == 2017
tab country if ratificationyear == 2018
tab country if ratificationyear == 2019
tab country if ratificationyear == 2020
tab country if ratificationyear == 2021

*Callaway and Sant'Anna (2021) Part
ssc install drdid, all replace
ssc install csdid, all replace

use nocontrols, clear
csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet //3166, jump positive and then negative

csdid_plot, group(2016) //nocontrols2016_1.jpg
csdid_plot, group(2017) //nocontrols2017_1.jpg

outreg2 using nocontrols.tex, replace

csdid emissions loggdp gdpsquared logpop agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr pcrenewable if year >= 2000, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) //

csdid_plot, group(2016) //nocontrols2016_2.jpg
csdid_plot, group(2017) //nocontrols2017_2.jpg

outreg2 using nocontrols2.tex, replace label

*By analysis group: developing developed eit ldc
use data_final3, clear //Reminder that developed=1, eit=2, developing=3, ldc separate variable

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000 & developmentstatus == 1, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //developed2016.jpg

outreg2 using developed2016.tex

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp if year >= 2000 & developmentstatus == 3, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //developing2016.jpg
csdid_plot, group(2017)	//developing2017.jpg
//2018 results all over the place

outreg2 using developing.tex

csdid emissions loggdp logpop gdpsquared agriculturepcgdp servicespcgdp v2x_polyarchy v2xeg_eqdr pcrenewable if year >= 2000 & developmentstatus == 3, ivar(numericcode) time(year) gvar(ratificationyear) method(drimp) notyet 

csdid_plot, group(2016) //developing2016_1.jpg
csdid_plot, group(2017) //developing2017_1.jpg

outreg2 using developing2.tex

reg emissions gdppc pop

