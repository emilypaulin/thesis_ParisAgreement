stop

* Emily Paulin

*Change directory to folder with all data files
cd "/Users/emilypaulin/Princeton/Academics/Senior Thesis/Data"

*Set log file
log close
log using 02222025.log

********************************************************************************
*Merging Data
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

*Merge of co2 and gdp/pop
use co2_long, clear
merge 1:1 countrycode year using gdp, gen(merge1) //8,329 matched
merge 1:1 country year using gdp, gen(merge1) //8,329 matched; so I'm pretty sure all of what's possible has been matched here. Going to merge on countrycode from now on. 
save merged1, replace //pop in thousands, gdppc in PPP terms, emissions in kton C

*Merge IMF data
use merged1, clear
merge 1:1 countrycode year using IMF_environmentalprotectionspending_pcGDP, gen (merge2) //3,528 matched, 84 not matched from using
sort merge2 //inspected, the countries that didn't merge were the West Bank, San Marino, and Kosovo
drop if merge2 == 2
rename pcGDP protectionspending_pcGDP
save merged2, replace

*Merge IMF data part 2
use merged2, clear
merge 1:1 countrycode year using IMF_environmentalprotectionRDspending_pcGDP, gen(merge3)
rename pcGDP protectionRDspending_pcGDP
sort merge3
drop if merge3 == 2
sort country year indicator
save merged3, replace

*Merge with absence of violence indicator
use merged3, clear
merge 1:1 countrycode year using WBabsenceofviolence_long, gen(merge4)
sort merge4
drop if merge4 == 2
sort country year
save merged4, replace

*Merge with Paris ratification dates
use merged4, clear
merge m:1 countrycode using parisratification, gen(merge5)
sort country year indicator
save merged5, replace

*Generate the dummy variable for whether Paris was ratified/date
use merged5, clear
gen ratified = .
replace ratified = 1 if ratificationyear <= year
replace ratified = 0 if ratified == .
gen time_to_ratification = year - ratificationyear
save merged5, replace

*Merge in the EIU data on GDP shares
*First prep the country codes
use merged5, clear
merge m:1 countrycode using countrycodes, gen(codesmerge)
drop if codesmerge==2
sort codesmerge country year
drop if codesmerge==1 //Gets rid of former USSR, former Yugoslavia, Serbia and Montenegro, Netherlands Antilles
drop codesmerge //None that didn't merge other than the ones dropped, obviously
save merged6, replace
merge 1:1 shortcountrycode year using gdpshares, gen(merge7)
drop if country == "Geography"
save merged7, replace

*Let's clean up this dataset a bit
order country shortcountrycode countrycode numericcode year
drop if merge5==2
drop iso2 indicator ctscode
drop if countrycode == ""
save data_final, replace

*Merge in wb dev indicators
use data_final, clear
merge 1:1 countrycode year using wbdevindicators_clean

********************************************************************************
*Let's redo this merge so it's neater*
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
keep if _merge == 3
sort country year
order country countrycode shortcountrycode numericcode year
drop _merge

save test, replace

*Merge with GDP
merge 1:1 countrycode year using gdp, gen(mergea)
*Algorithm to check if anything at all merged; if nothing, not worth keeping
gen mergecheck = mergea == 3
bysort countrycode: egen merged_count = total(mergecheck)
keep if merged_count > 0
drop mergecheck mergea
drop merged_count
save test, replace

*Paris ratification dates
merge m:1 countrycode using parisratification, gen(parismerge)
sort parismerge country year
sort country year 
replace ratificationyear = 2016 if countrycode == "USA" & year < 2020 //Not exactly sure if this is the right way to deal with this. "On 4 November 2019, the Government of the United States of America notified the Secretary-General of its decision to withdraw from the Agreement which took effect on 4 November 2020 in accordance with article 28 (1) and (2) of the Agreement."
replace ratificationyear = 2016 if countrycode == "PRI" & year < 2020
replace ratificationyear = 2021 if countrycode == "PRI" & year >= 2020
replace ratificationyear = 2016 if countrycode == "HKG"
//Taiwan is not a party to the agreement either, but is not considered a country. Possible control bc I do have emissions data?
drop parismerge

*Generate the dummy variable for whether Paris was ratified/date
gen ratified = .
replace ratified = 1 if ratificationyear <= year
replace ratified = 0 if ratified == .
gen time_to_ratification = year - ratificationyear
drop if emissions == . //See thinking doc for which countries aren't included

*GDP shares
merge 1:1 shortcountrycode year using gdpshares, gen(merge7) //data goes back to 1980 only
drop if country == "Geography" //why this is in there I have no idea
drop if countrycode == ""

gen mergecheck = merge7 == 3
bysort countrycode: egen merged_count = total(mergecheck)
keep if merged_count > 0
drop mergecheck merge7 merged_count
sort country year
save test, replace

*Absence of violence indicator
merge 1:1 countrycode year using WBabsenceofviolence_long, gen(absmerge)
gen mergecheck = absmerge == 3
bysort countrycode: egen merged_count = total(mergecheck)
sort merged_count countrycode year
drop if absmerge == 2
drop mergecheck absmerge merged_count
sort country year
save test, replace

*Merge IMF data
merge 1:1 countrycode year using IMF_environmentalprotectionspending_pcGDP, gen (merge2) 
drop if merge2 == 2
gen mergecheck = merge2 == 3
bysort countrycode: egen merged_count = total(mergecheck)
sort merged_count countrycode year
drop mergecheck merge2 merged_count
drop indicator iso2 ctscode
rename pcGDP protectionspending_pcGDP
save test, replace

*Merge IMF data part 2
merge 1:1 countrycode year using IMF_environmentalprotectionRDspending_pcGDP, gen(merge3)
sort merge3 countrycode year
drop if merge3 == 2
rename pcGDP protectionRDspending_pcGDP
drop indicator iso2 ctscode merge3
sort country year 
save test, replace

*CPIA, inflation, and Gini index
merge 1:1 countrycode year using wbdevindicators_clean //Taiwan isn't in here, and the rest that didn't merge were the year 1970.
sort _merge country year
drop if _merge == 2 
sort country year
drop _merge
save test, replace

*EIU corruption index
use test, clear
merge 1:1 shortcountrycode year using eiucorruption, gen(merge1)
sort merge1 country year
drop if merge1 == 2
sort country year

gen mergecheck = merge1 == 3
bysort countrycode: egen merged_count = total(mergecheck) 
sort merged_count country year //Comoros, Dominica, Guinea-Bissau, and Saint Lucia missing data
sort country year
drop merge1 mergecheck merged_count
save test, replace

*Merge in fuel percent of merchandise exports information
use test, clear
merge 1:1 countrycode year using fuelpcexports, gen(fuelmerge)
sort fuelmerge countrycode year
drop if fuelmerge == 2 //the master only merge was bc of 1970 for all countries.
sort countrycode year 
drop fuelmerge
save test, replace

gen loggdp = ln(gdp)
save test, replace

use test, clear
gen logpop = log(pop)
save data_final, replace

gen gdpsquared = (loggdp)^2
save data_final, replace

*Merge in Vdem data
use data_final, clear
merge 1:1 countrycode year using vdem, gen(merge)
sort merge countrycode year
drop if merge == 2
sort countrycode year
drop merge

save data_final, replace

gen logemissions = log(emissions)

order country countrycode shortcountrycode numericcode year C_group_IM24_sh emissions logemissions
save data_final, replace

*Drop 2 Vdem indices
use data_final, clear
save data_final1, replace //backup jic
drop v2x_partipdem v2x_egaldem
save data_final, replace

label var manufacturingpcgdp "Manufacturing Share of GDP"
label var agriculturepcgdp "Agriculture Share of GDP"
label var servicespcgdp "Services Share of GDP"
label var emissions "Emissions (kilotons per year)"
label var logemissions "Log Emissions"
label var gdppc "GDP Per Capita"
label var pop "Population (thousands)"
label var WBabsenceofviolence "World Bank Absence of Violence Index"
label var loggdp "Log of GDP"
label var logpop "Log of Population"
label var giniindex "Gini Index"
label var inflationgdpd "Inflation (GDP Deflator)"
label var inflationcpi "Inflation (Consumer Price Index)"
label var corruptionindex "Corruption Index"
label var fuelpcexports "Fuel Percent of Exports"
label var v2x_polyarchy "Electoral Democracy Index"
label var v2xeg_eqdr "Equal Distribution of Resources Index"
label var cpiagenderindex "CPIA Gender Index"
label var gdpsquared "Log GDP Squared"
save data_final, replace

*Merge in percent renewable energy
use data_final, clear
merge 1:1 numericcode year using pcrenewable, gen(merge1) //better than merging on name
sort merge1 country
drop if merge1==2
save data_final2, replace
save data_final, replace

label var pcrenewable "Renewable Energy Consumption Share (%)"
sort country year
drop merge1
save data_final, replace

*Merge in development status
import delimited "Development Status.csv", clear
rename v1 numericcode
drop if developmentstatus == .
replace ldcstatus = 0 if ldcstatus == .
save devstatus, replace
use devstatus, clear
use data_final, clear
merge m:1 numericcode using devstatus, gen(merge)
sort merge country

replace developmentstatus = 3 if country == "Dominican Republic"
replace merge = 3 if country == "Dominican Republic"
drop if merge == 2 | merge == 1
sort country year
save data_final3
