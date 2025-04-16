stop

* Emily Paulin

*Change directory to folder with all data files
cd "/Users/emilypaulin/Princeton/Academics/Senior Thesis/Data"

*Set log file
log close
log using 02222025.log

*Installs
ssc install coefplot
ssc install eventdd 
ssc install matsort 
ssc install reghdfe 
ssc install ftool
ssc install estout, replace

********************************************************************************
*Import and Clean Data
********************************************************************************

********************************************************************************
*Possible Dependent Variables
********************************************************************************

*EDGAR carbon emissions import and cleaning

import excel  "IEA_EDGAR_CO2_1970_2023.xlsx", sheet("TOTALS BY COUNTRY") clear

save co2, replace

rename A IPCC_annex
rename B C_group_IM24_sh
rename C Country_code
rename D Name
rename E Substance
rename (F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE AF AG AH AI AJ AK AL AM AN AO AP AQ AR AS AT AU AV AW AX AY AZ BA BB BC BD BE BF BG) x#, addnumber(1970)

save co2, replace

drop in 1/10
destring x1970-x2023, replace
rename Name country
drop Substance
drop IPCC_annex 
save co2, replace

*Co2 database is wide, this needs to be fixed before merge
use co2, clear 
reshape long x, i(country) j(year)
rename x emissions //I should check what units this actually is lmao
drop in 1/54
save co2_long, replace

rename Country_code countrycode
save co2_long, replace

*Renaming for merge -- not really useful anymore bc I merge on country codes
use co2_long, clear
replace country = "DR Congo" if country == "Congo_the Democratic Republic of the"
replace country = "Iran" if country == "Iran, Islamic Republic of"
replace country = "South Korea" if country == "Korea, Republic of"
replace country = "Laos" if country == "Lao People's Democratic Republic"
replace country = "Libya" if country == "Libyan Arab Jamahiriya"
replace country = "Taiwan" if country == "Taiwan_Province of China"
replace country = "North Macedonia" if country == "Macedonia, the former Yugoslav Republic of"
replace country = "Republic of Moldova" if country == "Moldova, Republic of"
replace country = "North Korea" if country == "Korea, Democratic People's Republic of"
replace country = "Tanzania" if country == "Tanzania_United Republic of"

drop if country == "Int. Aviation"
drop if country == "Int. Shipping"
save co2_long, replace

*IMF mitigation expenditures data
import delimited "IMF_mitigationexpenditures.csv", clear

forval i = 11/38 {
    local year = 1995 + `i' - 11
    rename v`i' x`year'
}

save IMF_mitigationexpenditures, replace

use IMF_mitigationexpenditures, clear
reshape long x, i(country indicator unit) j(year)
rename iso3 countrycode

save IMF_mitigationexpenditures, replace
use IMF_mitigationexpenditures, clear

*New database making
drop if unit == "Domestic Currency"
sort country indicator year
save IMF_mitigationexpenditures_pcGDP, replace

drop objectid source ctsname ctsfulldescriptor unit
rename x pcGDP
save IMF_mitigationexpenditures_pcGDP, replace

use IMF_mitigationexpenditures_pcGDP, clear
keep if indicator == "Expenditure on environment protection"
save IMF_environmentalprotectionspending_pcGDP, replace

use IMF_mitigationexpenditures_pcGDP, clear
keep if indicator == "Expenditure on environmental protection R&D"
save IMF_environmentalprotectionRDspending_pcGDP, replace

use IMF_mitigationexpenditures_pcGDP, clear
keep if indicator == "Expenditure on pollution abatement"
save IMF_pollutionabatementexpenditures_pcGDP

* Dataset for merging, direct from IBAN website
import delimited "countrycodes.csv", clear
rename v1 country
rename v2 shortcountrycode
rename v3 countrycode
rename v4 numericcode
save countrycodes, replace

*EIU corruption
import delimited "EIU corruption data.csv", clear
rename geographycode countrycode
rename geography country
rename q1-v98 x#, addnumber(1)
destring x1-x93, replace force
reshape long x, i(countrycode) j(quarter)
gen g = mod(quarter,4)
keep if g == 1
replace year = 2002 + (quarter - 1)/4
rename x corruptionindex
drop quarter series unit frequency g
rename countrycode shortcountrycode
save eiucorruption, replace
use eiucorruption, clear

*WB fuel export data
import delimited using "fuel exports.csv", clear
rename (v3 v4) (country countrycode)
rename v5-v68 x#, addnumber(1960)
drop in 1
drop v1 v2 x1960-x1970
drop if country == ""
reshape long x, i(countrycode) j(year)
rename x fuelpcexports
destring fuelpcexports, replace force
save fuelpcexports, replace

********************************************************************************
*Possible Control Variables
********************************************************************************

*GDP data from Penn World Tables
use "maddison2023_web.dta", clear

drop if gdppc == .
drop if pop == .
drop if year <= 1970
tab year
save gdp, replace

*Renaming countries, not super useful anymore because I merge on countrycodes
use gdp, clear
replace country = "Bolivia" if country == "Bolivia (Plurinational State of)"
replace country = "Cape Verde" if country == "Cabo Verde"
replace country = "DR Congo" if country == "D.R. of the Congo"
replace country = "Hong Kong" if country == "China, Hong Kong SAR"
replace country = "Iran" if country == "Iran (Islamic Republic of)"
replace country = "South Korea" if country == "Republic of Korea"
replace country = "Laos" if country == "Lao People's DR"
replace country = "Taiwan" if country == "Taiwan, Province of China"
replace country = "Venezuela" if country == "Venezuela (Bolivarian Republic of)"
replace country = "Sudan" if country == "Sudan (Former)"
replace country = "North Macedonia" if country == "TFYR of Macedonia"
replace country = "Cote d'Ivoire" if country == "Côte d'Ivoire"
replace country = "North Korea" if country == "D.P.R. of Korea"
replace country = "Tanzania" if country == "U.R. of Tanzania: Mainland"
drop if country == "Czechoslovakia" //Encompasses Czech Republic and Slovakia now
drop if country == "State of Palestine" //Not available in emissions data
save gdp, replace

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
drop merge1 merge2
save gdpshares, replace

*IEA data used by Aichele
cd "/Users/emilypaulin/Senior Fall/Senior Thesis/Data/Universite Laval IEA Database"
import delimited "db_countries.csv", clear
import delimited "db_country_traits.csv", clear
import delimited "db_members.csv", clear
import delimited "db_treaties.csv", clear

*World Bank absence of violence/terrorism indicator
import excel "WBgovernanceindicator.xlsx", clear //only 2000-2023
drop A B
rename C country
rename D countrycode
rename E x2000
rename F x2014
rename G x2015
rename H x2016
rename I x2017
rename J x2018
rename K x2019 
rename L x2020
rename M x2021
rename N x2022
rename O x2023
drop in 1
destring x*, replace force
drop in 215/219
save WBabsenceofviolence, replace

use WBabsenceofviolence, clear
reshape long x, i(country) j(year)
rename x WBabsenceofviolence
save WBabsenceofviolence_long, replace

*Renaming countries. Not useful anymore because of the country code merge.
use WBabsenceofviolence_long, clear
replace country = "Iran" if country == "Iran, Islamic Rep."
replace country = "Hong Kong" if country == "Hong Kong SAR, China"
replace country = "Cape Verde" if country == "Cabo Verde"
replace country = "Czech Republic" if country == "Czechia"
replace country = "Egypt" if country == "Egypt, Arab Rep."
replace country = "North Korea" if country == "Korea, Dem. People's Rep."
replace country = "South Korea" if country == "Korea, Rep."
replace country = "Kyrgyzstan" if country == "Kyrgyz Republic"
replace country = "Laos" if country == "Lao PDR"
replace country = "Macao" if country == "Macao SAR, China"
replace country = "Republic of Moldova" if country == "Moldova"
replace country = "Slovakia" if country == "Slovak Republic"
replace country = "Taiwan" if country == "Taiwan, China"
replace country = "Turkey" if country == "Turkiye"
replace country = "Venezuela" if country == "Venezuela, RB"
replace country = "State of Palestine" if country == "West Bank and Gaza"
replace country = "Yemen" if country == "Yemen, Rep."
replace country = "Congo" if country == "Congo, Rep."
replace country = "DR Congo" if country == "Congo, Dem. Rep."
//Sudan and South Sudan are both in this dataset separately, but I need to figure out which value to use for "former Sudan" -- check values
save WBabsenceofviolence_long_renamed, replace

import excel "polity5.xlsx", clear

*Paris ratification dates
import excel using "Paris Agreement Ratification Year.xlsx", clear
drop D E F G
rename A country
rename B countrycode
rename C ratificationyear
drop in 1
destring ratificationdate, replace
save parisratification, replace
replace countrycode = "VAT" if country == "Holy See"
drop if country == "European Union"
save parisratification, replace

*WB Development indicators: CPIA gender index, inflation (GDP deflator and consumer price index), and Gini coefficient
import delimited using "WB Development Indicators.csv", clear
rename v1 country
rename v2 countrycode
rename v3 indicator
drop v4
rename v5-v57 x#, addnumber(1971)
drop in 1
sort countrycode
drop in 1/5
save wbdevindicators, replace

keep if indicator == "Inflation, consumer prices (annual %)"
reshape long x, i(countrycode) j(year)
rename x inflationcpi
drop indicator
save inflationcpi, replace

use wbdevindicators, clear
keep if indicator == "Gini index"
reshape long x, i(countrycode) j(year)
rename x giniindex
drop indicator
save gini, replace

use wbdevindicators, clear
keep if indicator == "Inflation, GDP deflator (annual %)"
reshape long x, i(countrycode) j(year)
rename x inflationgdpd
drop indicator
save inflationgdpd, replace

use wbdevindicators, clear
keep if indicator == "CPIA gender equality rating (1=low to 6=high)"
reshape long x, i(countrycode) j(year)
rename x cpiagenderindex
drop indicator
save cpia, replace

use inflationcpi, clear
merge 1:1 countrycode year using gini, gen(merge1)
merge 1:1 countrycode year using inflationgdpd, gen(merge2)
merge 1:1 countrycode year using cpia, gen(merge3)

destring inflationcpi, replace force
destring giniindex, replace force
destring inflationgdpd, replace force
destring cpiagenderindex, replace force

drop merge1 merge2 merge3

save wbdevindicators_clean, replace

*Vdem data
use V-Dem-CY-Full+Others-v14
tab v2x_polyarchy //Electoral democracy (0-1) 26595
tab v2x_egaldem //Egalitarian democracy index: rights and freedoms, resource distribution, access to power 19208
tab v2xeg_eqdr //Equal distribution of resources index 19368
tab v2x_partipdem //Participatory democracy, 25982

rename country_text_id countrycode 
rename country_id numericcode
keep countrycode numericcode year v2x_polyarchy v2x_egaldem v2xeg_eqdr v2x_partipdem
drop if year <= 1970
save vdem, replace
tab countrycode
display 9014/53

use vdem, clear

*Energy intensity data
import excel using "Renewable energy share in the total final energy consumption (%) EG_FEC_RNEW.xlsx", clear //percent of renewable energy in final energy consumption
drop A-E H I 
drop AF-AZ
rename F numericcode
rename G country 
rename J-AE x#, addnumber(2000)
drop in 1
destring numericcode, replace
reshape long x, i(country) j(year)
rename x pcrenewable
destring pcrenewable, replace force
save pcrenewable, replace

import excel using "Energy intensity level of primary energy (megajoules per constant 2017 purchasing power parity GDP) EG_EGY_PRIM.xlsx", clear //energy intensity level of primary energy
