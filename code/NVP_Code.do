
clear 
clear mata
//log using NVP_code.log, replace
capture program drop _all

* start new program
program create_sub_exp
syntax, ///
    timeID(string) ///
    groupID(string) ///
    adoptionTime(string) ///
    focalAdoptionTime(int) ///
    kappa_pre(numlist) ///
    kappa_post(numlist)
    * Suppress output
  
        * Save dataset in memory, so we can call this function multiple times. 
        preserve

        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
        sum `timeID'
        local minTime = r(min)
        local maxTime = r(max)

        
        *variable to label sub-experiment if treated in focalAdoptionTime, 
        gen sub_exp = `focalAdoptionTime' if `adoptionTime' == `focalAdoptionTime'
        
        *Now fill in this variable for states with adoptionTime > focalAdoptionTime + kappa_post
        *note, this will include never treated, because adopt_year is ., which stata counts as infinity
        replace sub_exp = `focalAdoptionTime' if `adoptionTime' > `focalAdoptionTime' + `kappa_post'
        
        *Keep only treated and clean controls
        keep if sub_exp != .
        
        *gen treat variable in subexperiment
        gen treat = `adoptionTime' == `focalAdoptionTime'
        
        *gen event_time and 
        gen event_time = time - sub_exp
        
        *gen post variable
        gen post = event_time >= 0
        
        *trim based on kappa's: -kappa_pre < event_time < kappa_post
        keep if inrange(event_time, -`kappa_pre', `kappa_post')
        
        *keep if event_time >= -`kappa_pre' & event_time <= `kappa_post'
        gen feasible = 0 
        replace feasible = 1 if !missing(`adoptionTime')
        replace feasible = 0 if `adoptionTime' < `minTime' + `kappa_pre' 
        replace feasible = 0 if `adoptionTime' > `maxTime' - `kappa_post' 
        drop if `adoptionTime' < `minTime' + `kappa_pre' 

        * Save dataset
        compress
        save temp/subexp`focalAdoptionTime', replace
        restore
    
end

/* Create Weights */
*capture program drop _all
program compute_weights
syntax, ///
    treatedVar(string) ///
    eventTimeVar(string) ///
  groupID(string) ///
    subexpVar(string) 

  // Create weights
  bysort `subexpVar' `groupID': gen counter_treat = _n if `treatedVar' == 1
  egen n_treat_tot = total(counter_treat)
  by `subexpVar': egen n_treat_sub = total(counter_treat) 

  bysort `subexpVar'  `groupID': gen counter_control = _n if `treatedVar' == 0
  egen n_control_tot = total(counter_control)
  by `subexpVar': egen n_control_sub = total(counter_control) 


  gen stack_weight = 1 if `treatedVar' == 1
  replace stack_weight = (n_treat_sub/n_treat_tot)/(n_control_sub/n_control_tot) if `treatedVar' == 0
end

*Unemployment Rate - https://www.stats.gov.nl.ca/Statistics/Topics/labour/PDF/UnempRate_Monthly.pdf (webarchive)
import excel "Data\UnempRate_Monthly.xlsx", sheet("Stata") firstrow clear
foreach P in Alberta BritishColumbia Canada  NewBrunswick Manitoba NewfoundlandandLabrador NovaScotia Ontario PrinceEdwardIsland Quebec Saskatchewan {
	rename `P' UnEmp`P'
}

local nb_share = 775610 / (969383 + 154331 + 775610)
local pei_share = 154331 / (969383 + 154331 + 775610)
local ns_share = 969383 / (969383 + 154331 + 775610)
local sk_share = 1132505 / (1132505 + 1342153)
local mb_share = 1342153 / (1132505 + 1342153)

gen UnEmpMBSK = (`mb_share'*UnEmpManitoba)+(`sk_share'*UnEmpSaskatchewan)
gen UnEmpMaritimes = (`ns_share'*UnEmpNovaScotia)+ (`nb_share'*UnEmpNewBrunswick) + (`pei_share'*UnEmpPrinceEdwardIsland) 
drop UnEmpCanada UnEmpPrinceEdwardIsland 

reshape long UnEmp, i(Date) j(Province) str
gen Prov="BC" if Province=="BritishColumbia"
	replace Prov="ON" if Province=="Ontario"
	replace Prov="QC" if Province=="Quebec"
	replace Prov="AB" if Province=="Alberta"
	replace Prov="NB" if Province=="NewBrunswick"
	replace Prov="SK" if Province=="Saskatchewan"
	replace Prov="MB" if Province=="Manitoba"
	replace Prov="NS" if Province=="NovaScotia"
	replace Prov="NL" if Province=="NewfoundlandandLabrador"
	replace Prov= "MB & SK" if Province == "MBSK"
	replace Prov= "Maritimes" if Province == "Maritimes"
	
drop Province
rename Prov province

split Date, parse("-") gen(Month)
rename Month2 year
destring year, replace
replace year=2000+year

gen Month=1 if Month1=="Jan"
	replace Month=2 if Month1=="Feb"
	replace Month=3 if Month1=="Mar"
	replace Month=4 if Month1=="Apr"
	replace Month=5 if Month1=="May"
	replace Month=6 if Month1=="Jun"
	replace Month=7 if Month1=="Jul"
	replace Month=8 if Month1=="Aug"
	replace Month=9 if Month1=="Sep"
	replace Month=10 if Month1=="Oct"  
	replace Month=11 if Month1=="Nov"
	replace Month=12 if Month1=="Dec"
rename Month month
order year month 
sort year month province
drop Date Month1
save monthly_unemployment.dta, replace

**************Importing Covid Deaths Data***************
import delimited "Data\covid19-download.csv", clear
drop pruid prnamefr
label var prname "Province name (English)"
label var date "Epidemiological week end date"
label var reporting_week "Week number"
label var reporting_year "Year"
label var update "Report update"
label var totalcases "Total number of cases"
label var numtotal_last7 "Number of cases reported in the reporting week"
label var ratecases_total "Case rate per 100,000 population"
label var numdeaths "Total number of deaths"
label var numdeaths_last7 "Number of deaths reported in the reporting week"
label var ratedeaths "Death rate per 100,000  population"
label var ratecases_last7 "Case rate in the reporting week per 100,000 population"
label var ratedeaths_last7 "Death rate in the reporting week per 100,000 population"
label var numtotal_last14 "Number of cases reported in last 2 reporting weeks"
label var ratetotal_last14 "Case rate in last 2 reporting weeks per 100,000 population"
label var numdeaths_last14 "Number of deaths reported in last 2 reporting weeks"
label var ratedeaths_last14 "Death rate in last 2 weeks per 100,000 population"
label var avgcases_last7 "Average daily cases reported over the last reporting week"
label var avgincidence_last7 "Average daily cases reported over the last reporting week per 100,000 population"
label var avgdeaths_last7 "Average daily deaths reported over the last reporting week"
label var avgratedeaths_last7 "Average daily deaths reported over the last reporting week per 100,000"
split date, parse("/") gen(Date)
	rename Date1 Month
	rename Date2 Day
	rename Date3 Year
destring Month Day Year, replace
	replace Year=Year+2000 
gen Date=mdy(Month, Day, Year)
	format Date %td
	rename Date EndDate
egen newid = group(prname)
xtset newid EndDate, delta(7)
gen Prov="BC" if prname=="British Columbia"
	replace Prov="NB" if prname=="New Brunswick"
	replace Prov="MB" if prname=="Manitoba"
	replace Prov="NF" if prname=="Newfoundland and Labrador"
	replace Prov="NS" if prname=="Nova Scotia"
	replace Prov="ON" if prname=="Ontario"
	replace Prov="PE" if prname=="Prince Edward Island"
	replace Prov="QC" if prname=="Quebec"
	replace Prov="AB" if prname=="Alberta"
	replace Prov="Tot" if prname=="Canada"
	replace Prov="SK" if prname=="Saskatchewan"
	replace Prov="NT" if prname=="Northwest Territories"
	replace Prov="YT" if prname=="Yukon"
	replace Prov="NU" if prname=="Nunavut"
keep if Prov!="" & Prov!="YT" &  Prov!="NT" & Prov!="NU" &  Prov!="YT" 
keep if EndDate<=td(1july2023)					

gen CurWkAveDeaths=avgdeaths_last7
gen LastWkAveDeaths=L.avgdeaths_last7
gen NextWkAveDeaths=F.avgdeaths_last7
gen StartDate_1wk=EndDate-6
	format StartDate_1wk %td
	gen StartDate_1wkDay=day(StartDate_1wk)
gen SameM_1wk=(month(StartDate_1wk)==month(EndDate))	
gen DaysSameM_1wk=7 if month(EndDate-6)==month(EndDate)
	replace DaysSameM_1wk=6 if month(EndDate-6)==month(EndDate)-1 & month(EndDate-5)==month(EndDate)
	replace DaysSameM_1wk=5 if month(EndDate-5)==month(EndDate)-1 & month(EndDate-4)==month(EndDate)
	replace DaysSameM_1wk=4 if month(EndDate-4)==month(EndDate)-1 & month(EndDate-3)==month(EndDate)
	replace DaysSameM_1wk=3 if month(EndDate-3)==month(EndDate)-1 & month(EndDate-2)==month(EndDate)
	replace DaysSameM_1wk=2 if month(EndDate-2)==month(EndDate)-1 & month(EndDate-1)==month(EndDate)
	replace DaysSameM_1wk=1 if month(EndDate-1)==month(EndDate)-1 & month(EndDate)==month(EndDate)
	assert DaysSameM_1wk==7 if SameM_1wk==1

*Ideal Case: last day of month total - total from previous last day of month 
gen StartDateIs1stDOM=1 if StartDate_1wkDay==1  
gen StartDateIsLastDOM=1 if StartDate_1wkDay==31 | (StartDate_1wkDay==29 & month(StartDate_1wk)==2) | (StartDate_1wkDay==28 & month(StartDate_1wk)==2 & year(StartDate_1wk)!=2020) | (StartDate_1wkDay==30 & (month(StartDate_1wk)==9 | month(StartDate_1wk)==4 | month(StartDate_1wk)==6 | month(StartDate_1wk)==11))
gen EndDateIsLastDOM=1 if Day==31 | (Day==29 & month(EndDate)==2) | (Day==28 & month(EndDate)==2 & year(EndDate)!=2020) | (Day==30 & (month(EndDate)==9 | month(EndDate)==4 | month(EndDate)==6 | month(EndDate)==11))

keep if StartDateIs1stDOM==1 | EndDateIsLastDOM==1 | month(StartDate_1wk)!=month(EndDate) 
destring numdeaths_last7 , replace
gen Avgdeaths_last7=avgdeaths_last7 
	replace Avgdeaths_last7="." if avgdeaths_last7=="-" 
	destring Avgdeaths_last7, replace	
gen YM=ym(Year, Month) 
format YM %tm
gen TotDeathsEndThisMonth=numdeaths if EndDateIsLastDOM==1	
gen TotDeathsPriorMonth=L.numdeaths if L.EndDateIsLastDOM==1 
	replace TotDeathsPriorMonth=numdeaths-(DaysSameM_1wk*Avgdeaths_last7) if month(StartDate_1wk)!=month(EndDate) & Avgdeaths_last7!=. & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=numdeaths-numdeaths_last7 if StartDateIs1stDOM==1 & TotDeathsPriorMonth==.
		*Double Month Rep for Feb 2020 (2/1 & 2/29)
		assert numdeaths==0 if YM<=tm(2020m2)
		drop if EndDate==td(01feb2020)	
	replace TotDeathsPriorMonth=0 if YM==tm(2020m2)  & TotDeathsPriorMonth==.

	*Months with EndDateIsLastDOM==1 tend to have 2 observations  
tab date if EndDateIsLastDOM==1
	gen numdeaths_Oct2020=numdeaths if date=="10/31/20"
	gen numdeaths_July2021=numdeaths if date=="7/31/21"
	gen numdeaths_Apr2022=numdeaths if date=="4/30/22"
	gen numdeaths_Dec2022=numdeaths if date=="12/31/22"
foreach X in Oct2020 July2021 Apr2022 Dec2022 {
	by prname, sort: egen Numdeaths_`X'=max(numdeaths_`X')
}
	drop if date=="10/31/20" | date=="7/31/21" | date=="4/30/22" | date=="12/31/22"
	replace TotDeathsEndThisMonth=Numdeaths_Oct2020 if YM==tm(2020Oct) & TotDeathsEndThisMonth==.
	replace TotDeathsEndThisMonth=Numdeaths_Apr2022 if YM==tm(2022Apr) & TotDeathsEndThisMonth==.
	replace TotDeathsEndThisMonth=Numdeaths_Dec2022 if YM==tm(2022Dec) & TotDeathsEndThisMonth==.
	replace TotDeathsEndThisMonth=Numdeaths_July2021 if YM==tm(2021July) & TotDeathsEndThisMonth==.
xtset newid YM  
	assert TotDeathsPriorMonth==L.TotDeathsEndThisMonth if TotDeathsPriorMonth!=. & L.TotDeathsEndThisMonth!=.
	
tab date if TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(Avgdeaths_last7*2)) if date=="1/2/21" & TotDeathsPriorMonth==. & Avgdeaths_last7!=.
	replace TotDeathsPriorMonth=(numdeaths-(Avgdeaths_last7)) if date=="1/1/22" & TotDeathsPriorMonth==. & Avgdeaths_last7!=.

//browse YM date TotDeathsPriorMonth numdeaths Avgdeaths_last7 prname if YM>=tm(2023May) & (prname=="Prince Edward Island" | prname=="Newfoundland and Labrador"   | prname=="New Brunswick" | prname=="Nova Scotia")
*Returning to raw data for 2023 observations missing TotDeathsPriorMonth:
	*From 3/25/23 to 4/1/23, ∆numdeaths=0 in PEI & Newfoundland and Labrador ; ∆numdeaths=6 in NB; ∆numdeaths=9 in NS 
	replace TotDeathsPriorMonth=numdeaths-L.numdeaths if date=="4/1/23" & (prname=="Prince Edward Island" | prname=="Newfoundland and Labrador") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6/7))-L.numdeaths if date=="4/1/23" & prname=="New Brunswick" & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(9/7))-L.numdeaths if date=="4/1/23" & prname=="Nova Scotia" & TotDeathsPriorMonth==.
	*From 4/29/23 to 5/6/23, ∆numdeaths=0 in PEI & NB; ∆numdeaths=9 in NS; ∆numdeaths=4 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths-L.numdeaths if date=="5/6/23" & (prname=="Prince Edward Island" | prname=="New Brunswick") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6*(4/7)))-L.numdeaths if date=="5/6/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6*(9/7)))-L.numdeaths if date=="5/6/23" & prname=="Nova Scotia" & TotDeathsPriorMonth==.
	*From 5/27/23 to 6/3/23, ∆numdeaths=0 in PEI, NB, & NS; ∆numdeaths=3 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths-L.numdeaths if date=="6/3/23" & (prname=="Prince Edward Island" | prname=="New Brunswick" | prname=="Nova Scotia") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(3*(3/7)))-L.numdeaths if date=="6/3/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	*From 6/24/23 to 7/1/23, ∆numdeaths=0 in PEI, NB, & NS; ∆numdeaths=5 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths-L.numdeaths if date=="7/1/23" & (prname=="Prince Edward Island" | prname=="New Brunswick" | prname=="Nova Scotia") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(5/7))-L.numdeaths if date=="7/1/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	*From 2/25/23 to 3/4/23, ∆numdeaths=0 in Newfoundland and Labrador 
	*From 1/28/23 to 2/4/23, ∆numdeaths=0 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths-L.numdeaths if (date=="3/4/23" | date=="2/4/23") & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	
assert TotDeathsPriorMonth!=.
assert TotDeathsPriorMonth==L.TotDeathsEndThisMonth if L.TotDeathsEndThisMonth!=. & TotDeathsPriorMonth!=. & YM!=tm(2020feb)
keep prname TotDeathsPriorMonth YM newid Month Year  
gen Prov="BC" if prname=="British Columbia"
	replace Prov="NB" if prname=="New Brunswick"
	replace Prov="MB" if prname=="Manitoba"
	replace Prov="NF" if prname=="Newfoundland and Labrador"
	replace Prov="NS" if prname=="Nova Scotia"
	replace Prov="ON" if prname=="Ontario"
	replace Prov="PE" if prname=="Prince Edward Island"
	replace Prov="QC" if prname=="Quebec"
	replace Prov="AB" if prname=="Alberta"
	replace Prov="SK" if prname=="Saskatchewan"
	replace Prov="Tot" if prname=="Canada"
replace YM=YM-1
rename TotDeathsPriorMonth TotDeathsThisMonth
xtset newid YM  
gen TotDeathsPriorMonth=L.TotDeathsThisMonth
gen TotDeathsNextMonth=F.TotDeathsThisMonth
xtset, clear
order Month Year YM
gen january = 1 if Month == 1 
replace Month = Month - 1 
replace Month = 12 if january == 1 
replace Year = Year - 1 if Month == 12 
drop january
drop if prname == "Canada"
drop if prname == "Prince Edward Island"

save "temp\covid_temp.dta",replace
collapse (sum) TotDeathsThisMonth, by(Month Year newid)
gen province = "AB" if newid == 1
replace province = "BC" if newid == 2
replace province = "MB" if newid == 4
replace province = "NB" if newid == 5
replace province = "NF" if newid == 6
replace province = "NS" if newid == 8
replace province = "ON" if newid == 10
replace province = "QC" if newid == 12
replace province = "SK" if newid == 14

save "temp\covid_temp2.dta",replace

use "temp\covid_temp.dta",replace
drop if prname == "Alberta"
drop if prname == "British Columbia"
drop if prname == "Ontario"
drop if prname == "Quebec"
drop if prname == "Newfoundland and Labrador"

replace newid = 4 if newid == 14
replace newid = 5 if newid == 8 | newid == 11

collapse (sum) TotDeathsThisMonth, by(Month Year newid)

gen province = "MB & SK" if newid == 4
replace province = "Maritimes" if newid == 5

append using "temp\covid_temp2.dta"

sort province Year Month
rename Year year
rename Month month
drop newid
save MonthlyCovidCasesCanada.dta, replace

************************Import Covid Restrictions*****************************
*COVID Policies
import excel "Data\COVID19Restrictions_3310049701.xlsx", sheet("3310049701-eng(2)") firstrow clear
reshape long Apr Aug Dec Feb Jan July June Mar May Oct Nov Sept, i(Province Policy) j(Year) str
foreach X in Apr Aug Dec Feb Jan July June Mar May Oct Nov Sept {
	rename `X' Month_`X' 
}
reshape long Month_, i(Province Policy Year) j(Month) str
rename Month_ Index
reshape wide Index, i(Province Month Year) j(Policy) str

foreach X in CovidRestrictionIndex InternalMvmtRestrictions NonEssRetailerRestrictions SchoolClosing  WorkplaceClosing {
	rename Index`X' `X' 
}
replace Month="1" if  Month=="Jan"
replace Month="2" if  Month=="Feb"
replace Month="3" if  Month=="Mar"
replace Month="4" if  Month=="Apr"
replace Month="5" if  Month=="May"
replace Month="6" if  Month=="June"
replace Month="7" if  Month=="July"
replace Month="8" if  Month=="Aug"
replace Month="9" if  Month=="Sept"
replace Month="10" if  Month=="Oct"  
replace Month="11" if  Month=="Nov"
replace Month="12" if  Month=="Dec"

replace Year="2020" if Year=="_2020"  
replace Year="2021" if Year=="_2021" 
replace Year="2022" if Year=="_2022"  

destring Month Year, replace
rename NonEssRetailerRestrictions NonEssRetRestrictions
gen YM=ym(Year,Month)
format YM %tm

gen Prov="BC" if Province=="British Columbia"  
	replace Prov="NS" if Province=="Nova Scotia"
	replace Prov="PE" if Province=="Prince Edward Island"
	replace Prov="NB" if Province=="New Brunswick"
	replace Prov="NT" if Province=="Northwest Territories"
	replace Prov="NU" if Province=="Nunavut"
	replace Prov="MB" if Province=="Manitoba"
	replace Prov="AB" if Province=="Alberta"
	replace Prov="SK" if Province=="Saskatchewan"
	replace Prov="QC" if Province=="Quebec"
	replace Prov="ON" if Province=="Ontario"
	replace Prov="NF" if Province=="Newfoundland and Labrador"
	replace Prov="YT" if Province=="Yukon"
	
rename Year year
rename Month month

drop if Prov == "YT"| Prov=="NT" | Prov=="NU"
replace Province = Prov
rename Province province
save "temp\covid_policy_temp.dta", replace 
keep if Prov == "MB" | Prov == "SK" | Prov == "NB" | Prov == "NS" | Prov == "PE"

gen id = 1 if Prov == "MB" | Prov == "SK" 
replace id = 2 if  Prov == "NB" | Prov == "NS" | Prov == "PE"

gen pop=969383 if Prov=="NS"
replace pop=154331 if Prov=="PE"
replace pop=775610 if Prov=="NB"
replace pop=1132505 if Prov=="SK"
replace pop=1342153 if Prov=="MB"
replace pop=4371000 if Prov=="AB"
replace pop=5071000 if Prov=="BC"
replace pop=14570000 if Prov=="ON"
replace pop=8485000 if Prov=="QC"

collapse (mean) CovidRestrictionIndex InternalMvmtRestrictions ///
                NonEssRetRestrictions SchoolClosing WorkplaceClosing ///
                [aweight=pop], by(month year id)
				
gen province = "MB & SK" if id == 1 
replace province = "Maritimes" if id == 2 
drop id
append using "temp\covid_policy_temp.dta" 

drop Prov YM 
save CanadaCovidPolicies.dta, replace

//E-Cigarette Sales Cleaning
use "Data\NielsenVapingMaster6.dta", clear
*MFP: Appears 949 duplicate rows for 2022
duplicates drop


/*
2021 SK pop = 1,132,505; 2021 MB pop = 1,342,153)
2021 NS pop = 969,383; 2021 PEI pop = 154,331; 2021 NB pop = 775,610
NS portion = 969,383 / (969,383 + 154,331 + 775,610) = 51.0%
*/

local nb_share = 775610 / (969383 + 154331 + 775610)
local pei_share = 154331 / (969383 + 154331 + 775610)
local ns_share = 969383 / (969383 + 154331 + 775610)
local sk_share = 1132505 / (1132505 + 1342153)
local mb_share = 1342153 / (1132505 + 1342153)

rename Column1 price_per_unit
destring Nicotineconetentmgml, replace

replace nonflavsflav = "Tobacco" if inlist(flav,"tobacco","Tobacco")
replace nonflavsflav = "Non-flavoured" if inlist(flav,"no","NO","No")
replace nonflavsflav = "Unknown" if inlist(flav,"Unknown","unknown","nn","","yes")
replace nonflavsflav = "Flavoured" if inlist(flav,"Fruit","Candy","Fruit + Mint","Mint")
replace nonflavsflav = "Mint" if inlist(flav,"Menthol", "Mint", "Mint +Menthol", "mint", "menthol", "Tobacco + Menthol", "Tobacco + Mint", "Tobacco + mint")

tab flav nonflavsflav, miss
tab nonflavsflav, miss
*MFP: A lot of 2014 values have NA, questionable data quality in 2014. 
replace dollars="" if dollars=="NA"
replace units="" if units=="NA"
destring dollars, replace
destring units, replace

//Data not collected regularly until Dec. 2017.
drop if startyear<=2017

replace Nicotineconetentmgml="" if Nicotineconetentmgml=="Unknown"
destring Nicotineconetentmgml, replace

//Do not need devices. Only looking at products which contain nicotine
tab Nicotineconetentmgml startyear if producttype=="device only", miss
tab Nicotineconetentmgml startyear if producttype=="charger", miss
tab Nicotineconetentmgml startyear if producttype=="skin", miss
tab Nicotineconetentmgml startyear if producttype=="rechargeable", miss

drop if producttype=="device only" | producttype=="charger" | producttype=="skin" | producttype=="rechargeable"
tab producttype

tab producttype, sum(Nicotineconetentmgml)
tab channel startyear
*MFP: channel=="GDC" appears in Maritimes in only Dec. 2021. I believe that this is supposed to be GDM.
replace channel="GDM" if channel=="GDC"
replace channel="G&C" if channel=="C&G"
tab channel startyear

//Generate Stats for analytic time period
preserve 
drop if startyear == 2018 & startmonth<6
drop if startyear == 2023 & startmonth>6
sum units if channel == "GDM"
sum units if channel == "G&C"
//57.411 million units from G&C; 0.908 million units from GDM; 98.4% G&C
restore 

//Restricts our analysis to G&C
keep if channel == "G&C"

//Nictoine missing in 27% of Kits, 15% of disposables, 8% of e liquid, <1% of cartridges
//A lot of disposables and e liquid with no nicotine in 2018
tab Nicotineconetentmgml startyear if producttype=="cartridge", miss
tab Nicotineconetentmgml startyear if producttype=="disposable", miss
tab Nicotineconetentmgml startyear if producttype=="e liquid", miss
tab Nicotineconetentmgml startyear if producttype=="kit", miss

replace province="MB & SK" if inlist(province,"MN and  SK","MN and SK", "MN & SK")
*MFP: “Maritimes” are Nova Scotia, New Brunswick, and Prince Edward Island; Newfoundland part of Maritimes but not in the data.
tab province, miss

//Reconfigure to Monthly 
*MFP: Check that no duplicates
duplicates drop province startyear startmonth startday UPC channel, force

egen province_dum = group(province)
egen time = group(startyear startmonth startday)

gen product_volume = .
replace product_volume = 1.9*2 if (Brand=="VUSE" | Brand=="VYPE") /*& producttype=="cartridge"*/
replace product_volume = 0.7*4 if Brand=="JUUL" & producttype=="cartridge"
replace product_volume = 1.5*2 if Brand=="VEEV" & producttype=="cartridge"
replace product_volume = 1.7*2 if Brand=="LOGIC" & producttype=="cartridge"
replace product_volume = 2*3 if Brand=="ALLO" & producttype=="cartridge"
replace product_volume = 1.5*2 if Brand=="MYBLU" & producttype=="cartridge"
replace product_volume = 2*3 if Brand=="Z PODS" & producttype=="cartridge"
replace product_volume = 0.9*4 if Brand=="MYLE" & producttype=="cartridge"
replace product_volume = 1.9*2 if Brand=="RELX" & producttype=="cartridge"
replace product_volume = 1.2*3 if Brand=="STIG" & producttype=="cartridge"
replace product_volume = 2*3 if Brand=="STLTH" & producttype=="cartridge"
replace product_volume = 2*3 if Brand=="ZIIPLAB" & producttype=="cartridge"
replace product_volume = 4 if Brand=="POP" & producttype=="disposable" & (strpos(Description, "EXTRA") | strpos(Description, "4ML"))
replace product_volume = 1.2 if Brand=="POP" & producttype=="disposable" & product_volume==.
replace product_volume = 3.5 if Brand=="PUFF" & producttype=="disposable"
replace product_volume = 3.8 if Brand=="ALLO" & producttype=="disposable"
replace product_volume = 1.2 if Brand=="DOSE" & producttype=="disposable"
*MFP: Only 1 type of both GCORE and GHOST according to description.
replace product_volume = 4 if Brand=="GCORE" & producttype=="disposable"
replace product_volume = 6 if Brand=="GHOST" & producttype=="disposable"
replace product_volume = 1.2 if Brand=="STIG" & producttype=="disposable"

forvalues i = 1/50 {
replace product_volume = `i' if strpos(Description, "`i'ML") & product_volume==.
}

forvalues i = 0/60 {
replace Nicotineconetentmgml = `i' if strpos(Description, "`i'MG") & Nicotineconetentmgml == . 
}

forvalues i = 0/60 {
replace Nicotineconetentmgml = `i' if strpos(Description, "`i' MG") & Nicotineconetentmgml == . 
}

replace Nicotineconetentmgml = 0 if strpos(Description, "0% NICOTINE") & Nicotineconetentmgml == .

sort UPC startyear

bysort UPC : replace Nicotineconetentmgml = Nicotineconetentmgml[_n-1] if missing( Nicotineconetentmgml )
bysort UPC : replace Nicotineconetentmgml = Nicotineconetentmgml[_n+1] if missing( Nicotineconetentmgml )

gen volume = product_volume*units
gen nicotine = Nicotineconetentmgml* volume

tab flav nonflavsflav, miss

gen tob_unflav_flavored = 1 if nonflavsflav == "Non-flavoured" | nonflavsflav == "Tobacco"
replace tob_unflav_flavored = 0 if tob_unflav_flavored == . 
tab tob_unflav_flavored

gen flavored = 1 if nonflavsflav == "Flavoured"
replace flavored = 0 if flavored == . 
tab flavored

gen mint = 1 if nonflavsflav == "Mint"
replace mint = 0 if mint == . 
tab mint

gen units_tob_unflav = units if tob_unflav_flavored == 1 
gen units_flavored = units if flavored == 1 
gen units_mint = units if mint == 1

gen units_stand = units if product_volume != . 
gen units_tob_unflav_stand = units if tob_unflav_flavored == 1 & product_volume != .
gen units_flavored_stand = units if flavored == 1 & product_volume != .
gen units_mint_stand = units if mint == 1 & product_volume != .

gen volume_tob_unflav = product_volume*units if tob_unflav_flavored == 1 
gen volume_flav = product_volume*units if flavored == 1
gen volume_mint = product_volume*units if mint == 1

//Generate Stats for analytic time period
preserve 
drop if startyear == 2018 & startmonth<6
drop if startyear == 2023 & startmonth>6
sum units if product_volume != . 
sum units if product_volume == . 
//56.881 million units with volume; 0.530 million units with volume missing; 0.92% with volume missing

sum units if nonflavsflav == "Unknown"
sum units if nonflavsflav != "Unknown"
//57.398342 million units with known flavor; 0.013174 million with flavor unknown

sum units if producttype == "cartridge"
//53.945 million units; 94.0%

restore 


//preserve
//collapse (mean) product_volume Nicotineconetentmgml [aw=units]
//restore 


collapse (sum) units volume units_tob_unflav units_flavored units_mint units_stand units_tob_unflav_stand units_flavored_stand units_mint_stand volume_tob_unflav volume_flav volume_mint nicotine, by(province_dum time province enddate endmonth endday endyear startdate startmonth startday startyear)

gen days_in_period = enddate - startdate 
gen units_per_day = units/days_in_period
gen volume_per_day = volume/days_in_period
gen nicotine_per_day = nicotine/days_in_period

gen units_tob_unflav_per_day = units_tob_unflav/days_in_period
gen units_flavored_per_day = units_flavored/days_in_period
gen units_mint_per_day = units_mint/days_in_period

gen units_stand_per_day = units_stand/days_in_period
gen units_tob_unflav_stand_per_day = units_tob_unflav_stand/days_in_period
gen units_flavored_stand_per_day = units_flavored_stand/days_in_period
gen units_mint_stand_per_day = units_mint_stand/days_in_period

gen volume_tob_unflav_per_day = volume_tob_unflav/days_in_period
gen volume_flav_per_day = volume_flav/days_in_period
gen volume_mint_per_day = volume_mint/days_in_period

expand days_in_period
sort province time

bysort startdate province : gen date = startdate + _n - 1

sort province time date

gen ym = mofd(date)
format ym %tm

collapse (sum) units = units_per_day volume = volume_per_day units_tob_unflav = units_tob_unflav_per_day units_flavored = units_flavored_per_day units_mint = units_mint_per_day units_stand = units_stand_per_day units_tob_unflav_stand = units_tob_unflav_stand_per_day units_flavored_stand = units_flavored_per_day units_mint_stand = units_mint_stand_per_day volume_tob_unflav = volume_tob_unflav_per_day volume_flav = volume_flav_per_day volume_mint = volume_mint_per_day nicotine = nicotine_per_day, by(province_dum ym province)

gen month = month(dofm(ym))
gen year = year(dofm(ym))

egen time = group(year month)

gen pop=.
replace pop=969383 + 154331 + 775610 if province=="Maritimes"
replace pop=1132505 + 1342153 if province=="MB & SK"
replace pop=4371000 if province=="AB"
replace pop=5071000 if province=="BC"
replace pop=14570000 if province=="ON"
replace pop=8485000 if province=="QC"


//Stats for zeros in analytic sample 
preserve 
drop if year == 2018 & month<7
drop if year == 2023 & month>6

sum units_mint units_flavored


tab units_flavored, missing //5% with 0 flavored sales
tab units_mint, missing //1% with 0 mint sales

restore 

replace units_mint = 1 if units_mint == 0 
replace units_flavored = 1 if units_flavored == 0 

gen units_per_capita = units/pop
gen units_flavored_per_capita = units_flavored/pop
gen units_mint_per_capita = units_mint/pop
gen units_tob_unflav_per_capita = units_tob_unflav/pop

gen nicotine_per_capita = nicotine/pop

gen log_units_per_capita = ln(units_per_capita)
gen log_units_flavored_per_capita = ln(units_flavored_per_capita)
gen log_units_tob_unflav_per_capita = ln(units_tob_unflav_per_capita)
gen log_units_mint_per_capita = ln(units_mint_per_capita)

//Create Standardized Units
//Create a variable for average volume across all time
egen total_volume = total(volume)
egen total_units = total(units_stand)

egen total_volume_flavored = total(volume_flav)
egen total_units_flavored = total(units_flavored_stand)

egen total_volume_unflav = total(volume_tob_unflav)
egen total_units_unflav = total(units_tob_unflav_stand) 

egen total_volume_mint = total(volume_mint)
egen total_units_mint = total(units_mint_stand) 

gen global_average_volume = total_volume/total_units
gen global_average_volume_flav = total_volume_flavored/total_units_flavored
gen global_average_volume_unflav = total_volume_unflav/total_units_unflav
gen global_average_volume_mint = total_volume_mint/total_units_mint

gen stand_units_per_capita = volume/global_average_volume/pop

gen stand_units_flav = volume_flav/global_average_volume_flav
gen stand_units_unflav = volume_tob_unflav/global_average_volume_unflav
gen stand_units_mint = volume_mint/global_average_volume_mint

replace stand_units_flav = 1 if stand_units_flav == 0 
replace stand_units_unflav = 1 if stand_units_unflav == 0 
replace stand_units_mint = 1 if stand_units_mint == 0

gen stand_units_flav_per_capita = stand_units_flav/pop
gen stand_units_unflav_per_capita = stand_units_unflav/pop
gen stand_units_mint_per_capita = stand_units_mint/pop

gen lstand_units_per_capita = ln(stand_units_per_capita)
gen lstand_units_flav_per_capita = ln(stand_units_flav_per_capita)
gen lstand_units_unflav_per_capita = ln(stand_units_unflav_per_capita)
gen lstand_units_mint_per_capita = ln(stand_units_mint_per_capita)

gen ENDSTax_Perc = 0
replace ENDSTax_Perc = 13 if province == "BC" & year>= 2020
replace ENDSTax_Perc = (16/30)*20*`ns_share' if province=="Maritimes" & year==2020 & month==9 
replace ENDSTax_Perc = 20 * `ns_share' if province == "Maritimes" & ((year==2020 & month>=10) | year>=2021)
replace ENDSTax_Perc = 20 * `sk_share' if province=="MB & SK" & ((year>=2021 & month>=9) | year>=2022)

gen ENDSTax_PerML = 0 
replace ENDSTax_PerML = (16/30)*50*`ns_share' if province=="Maritimes" & year==2020 & month==9 
replace ENDSTax_PerML = 50 * `ns_share' if province == "Maritimes" & ((year==2020 & month>=10) | year>=2021)

gen cig_tax = .
replace cig_tax = 25 if province=="AB"
replace cig_tax = ((24/31)*25)+((7/31)*27.5) if province=="AB" & month == 10 & year == 2019
replace cig_tax = 27.5 if province=="AB" & ((month>= 11 &year>=2019)| year>=2020)
replace cig_tax = 24.7 if province=="BC"
replace cig_tax = 27.5 if province=="BC" & ((month>=4 & year>=2018) | year>=2019)
replace cig_tax = 29.5 if province=="BC" & ((month>=8 & year>=2020) | year>=2021)
replace cig_tax = 32.5 if province=="BC" & ((month>=7 & year>=2021) | year>=2022)
replace cig_tax = 27 * `sk_share' + 29.5 * `mb_share'  if province=="MB & SK"
replace cig_tax = 27 * `sk_share' + 30 * `mb_share'  if province=="MB & SK" & ((month>= 7 & year >= 2019) | year>=2020)
replace cig_tax = ((23/31)*27 * `sk_share')+((8/31)*29 * `sk_share') + (30 * `mb_share')  if province=="MB & SK" & (month == 3 & year == 2022)
replace cig_tax = 29 * `sk_share' + 30 * `mb_share'  if province=="MB & SK" & ((month>= 4 & year >= 2022) | year>=2023)
replace cig_tax = 25.52 * `nb_share' + 27.52 * `ns_share' + 25 * `pei_share' if province=="Maritimes"
replace cig_tax = 25.52 * `nb_share' + ((25/29)*27.52 * `ns_share') + ((4/29)*29.52 * `ns_share') + 25 * `pei_share' if province=="Maritimes" & (month == 2 & year==2020) 
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + 25 * `pei_share' if province=="Maritimes" & ((month>=3 & year==2020) | year>=2021)
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + (16/31*25 * `pei_share')+(15/31*27.52 * `pei_share') if province=="Maritimes" & (month==7 & year==2020)
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + 27.52 * `pei_share' if province=="Maritimes" & ((month>=8 & year==2020) | year>=2021)
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + (6/31*27.52 * `pei_share')+(25/31*29.52 * `pei_share') if province=="Maritimes" & (month==5 & year==2022)
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + 29.52 * `pei_share' if province=="Maritimes" & ((month>=6 & year==2022) | year>=2023)
replace cig_tax = 14.9 if province=="QC" 
replace cig_tax = (8/28*14.9)+(20/28*18.9) if province=="QC" & (month==2 & year==2023)
replace cig_tax = 18.9 if province=="QC" & ((month>=3 & year==2023) |year>=2024)
replace cig_tax = 16.475 if province=="ON"
replace cig_tax = (28/31*16.475)+(3/31*18.475) if province=="ON" & (month==3 & year==2018)
replace cig_tax = 18.475 if province=="ON" & ((month>=4 & year==2018) |year>=2019)

tab cig_tax

gen ecig_flavor = 0
replace ecig_flavor = (16/30) if province == "BC" & month == 9 & year == 2020
replace ecig_flavor = 1 if province=="BC" & ((month>9 & year==2020 )| year>=2021)
replace ecig_flavor = 1 if province=="ON" & ((month>=7 & year==2020) | year>=2021)
replace ecig_flavor = `ns_share' if province=="Maritimes" & ((month>=4 & year==2020) | year>=2021)
replace ecig_flavor = `pei_share' + ecig_flavor if province=="Maritimes" & ((month>=3 & year==2021) | year>=2022)
replace ecig_flavor = `nb_share' + ecig_flavor if province=="Maritimes" & ((month>=9 & year==2021) | year>=2022)
replace ecig_flavor = `sk_share' if province=="MB & SK" & ((month>=9 & year==2021) | year>=2022)

gen ecig_nicotine = 0
replace ecig_nicotine = (16/30) if province == "BC" & month == 9 & year == 2020
replace ecig_nicotine = 1 if province=="BC" & ((month>9 & year==2020 )| year>=2021)
replace ecig_nicotine = `ns_share' if (province=="Maritimes") & ((month>=9 & year==2020) | year>=2021)
replace ecig_nicotine = 1 if province=="ON" & ((month>=7 & year==2020) | year>=2021)
replace ecig_nicotine = 1  if ((month>=8 & year==2021) | year>=2022)

gen trade_bubble = 0 
replace trade_bubble = 1 if province == "Maritimes" & year == 2020 & month>=7 & month <=12

gen ban_minor_sales = 1 
replace ban_minor_sales = 0 if province == "AB" & year == 2018 & month<5

gen flavor_treat_period = . 
replace flavor_treat_period = 28 if province == "Maritimes" // April 2020
replace flavor_treat_period = 31 if province == "ON"   // July 2020
replace flavor_treat_period = 33 if province == "BC"		// September 2020
replace flavor_treat_period = 45 if province == "MB & SK"   // September 2021

gen ttt_flavor = time - flavor_treat_period

merge 1:1 year month province using "monthly_unemployment.dta", generate(_merge1)
keep if _merge1 == 3

merge m:1 month year province using "MonthlyCovidCasesCanada.dta", generate(_merge2)
drop if _merge2 == 2
replace TotDeathsThisMonth = 0 if TotDeathsThisMonth == . 
gen CvdDeathsPC = TotDeathsThisMonth/pop

merge m:1 month year province using "CanadaCovidPolicies.dta", generate(_merge3)
drop if _merge3 == 2
replace CovidRestrictionIndex = 0 if CovidRestrictionIndex == . 
replace InternalMvmtRestrictions = 0 if InternalMvmtRestrictions == . 
replace NonEssRetRestrictions = 0 if NonEssRetRestrictions == . 
replace SchoolClosing = 0 if SchoolClosing == . 
replace WorkplaceClosing = 0 if WorkplaceClosing == . 

save analytic.dta,replace 

//Google Trends Data
import delimited "data\google_trends4.csv", clear
drop date
save google_data.dta, replace 
drop if province == "PE" //Lots of missing for Prince Edward Island

*MFP: All populations are as of 2019
gen pop=.
replace pop=969383 if province=="NS"
replace pop=154331 if province=="PE"
replace pop=775610 if province=="NB"
replace pop=1342153 if province=="MB"
replace pop=1132505  if province=="SK"
replace pop=4371000 if province=="AB"
replace pop=5071000 if province=="BC"
replace pop=14570000 if province=="ON"
replace pop=8485000 if province=="QC"
replace pop=38780 if province=="NU"
replace pop=521542 if province=="NL"
replace pop=44412 if province=="YT"


merge 1:1 month year province using monthly_unemployment.dta
keep if _merge == 3

merge 1:1 year month province using MonthlyCovidCasesCanada.dta, generate(_merge2)
drop if _merge2 == 2
replace TotDeathsThisMonth = 0 if TotDeathsThisMonth == . 
gen CvdDeathsPC = TotDeathsThisMonth/pop

merge 1:1 year month province using CanadaCovidPolicies, generate(_merge3)
drop if _merge3 == 2
replace InternalMvmtRestrictions = 0 if InternalMvmtRestrictions == . 
replace NonEssRetRestrictions = 0 if NonEssRetRestrictions == . 

tab shopping province
tab interest province
tab ecig_search province

replace interest = 7 if interest == 0 //Replace not calculated scores with half of lowest value
replace shopping = 7 if shopping == 0

egen time = group(year month)
egen province_dum = group(province)
sort province time

replace pop=44826 if province=="NT"

gen ecig_flavor = 0
replace ecig_flavor = 1 if province=="NS" & ((month>=4 & year==2020) | year>=2021)
replace ecig_flavor = 1 if province=="ON" & ((month>=7 & year==2020) | year>=2021)
replace ecig_flavor = 1 if province=="BC" & ((month>9 & year==2020) | year>=2021)
replace ecig_flavor = 0.5 if province=="BC" & month==9 & year==2020
replace ecig_flavor = 1 if province=="PE" & ((month>=3 & year==2021) | year>=2022) //PE not in dataset
replace ecig_flavor = 1 if province=="NB" & ((month>=9 & year==2021) | year>=2022)
replace ecig_flavor = 1 if province=="SK" & ((month>=9 & year==2021) | year>=2022)
replace ecig_flavor = 1 if province=="QC" & ((month>=11 & year==2023) | year>=2024)

gen flavor_treat_period = . 
replace flavor_treat_period = 28 if province == "NS"		// April 2020
replace flavor_treat_period = 31 if province == "ON"		// July 2020
replace flavor_treat_period = 33 if province == "BC"		// September 2020
replace flavor_treat_period = 45 if province == "NB"		// September 2021
replace flavor_treat_period = 45 if province == "SK"		// September 2021
//replace flavor_treat_period = 71 if province == "QC"		// November 2023

gen ttt_flavor = time - flavor_treat_period

gen cig_tax = .
replace cig_tax = 25 if province=="AB"
replace cig_tax = (24/31*25)+ (7/31*27.5) if province=="AB" & month==10 & year==2019
replace cig_tax = 27.5 if province=="AB" & ((month>=11 & year==2019) | year>=2020)
replace cig_tax = 24.7 if province=="BC"
replace cig_tax = 27.5 if province=="BC" & ((month>=4 & year==2018) | year>=2019)
replace cig_tax = 29.5 if province=="BC" & (month>=8 & year==2020) | year>=2021
replace cig_tax = 32.5 if province=="BC" & ((month>=7 & year==2021) | year>=2022)
replace cig_tax = 27 if province=="SK"
replace cig_tax = 29.5 if province=="MB"
replace cig_tax = 30 if province=="MB" & ((month>=7 & year==2019) | year>=2020)
replace cig_tax = 25.52 if province=="NB"
replace cig_tax = 27.52 if province=="NS"
replace cig_tax = (25/29*27.52)+(4/29*29.52) if province=="NS" & month==2 & year==2020
replace cig_tax = 29.52 if province=="NS" & ((month>=3 & year==2020) | year>=2021)
replace cig_tax = 25 if province=="PE"
replace cig_tax = (14/31*25)+(17/31*27.52) if province=="PE" & month==7 & year==2020
replace cig_tax = 27.52 if province=="PE" & ((month>=8 & year==2020) | year>=2021)
replace cig_tax = 14.9 if province=="QC" 
replace cig_tax = 16.475 if province=="ON"
replace cig_tax = (28/31*16.475)+(3/31*18.475) if province=="ON" & month==3 & year==2018
replace cig_tax = 18.475 if province=="ON" & ((month>=4 & year>=2018) | year>=2019)
replace cig_tax = (23/31*27)+(8/31*29) if province=="SK" & month==3 & year==2022
replace cig_tax = 29 if province=="SK" & ((month>=4 & year==2022) | year>=2023)
replace cig_tax = 30 if province=="NU"
replace cig_tax = 24.5 if province=="NL"
replace cig_tax = 29.5 if province=="NL" & ((month>=10 & year==2020) | year>=2021)
replace cig_tax = 32.5 if province=="NL" & ((month>=6 & year==2021) | year>=2022)
replace cig_tax = 25 if province=="YT"
replace cig_tax = 30 if province=="YT" & ((month>=4 & year==2018) | year>=2019)
replace cig_tax = 31 if province=="YT" & year>=2021
replace cig_tax = 32 if province=="YT" & year>=2023
replace cig_tax = 30.4 if province=="NT"
replace cig_tax = 34.4 if province=="NT" & ((month>=8 & year==2022) | year>=2023)
replace cig_tax = (6/31*27.52) + (25/31*29.52) if province=="PE" & month==5 & year==2022
replace cig_tax = 29.52 if province=="PE" & ((month>=6 & year==2022) | year>=2023)
replace cig_tax = (8/28*14.9)+(20/28*18.9) if province=="QC" & month==2 & year==2023
replace cig_tax = 18.9 if province=="QC" & ((month>=3 & year==2023) | year>=2024)

gen ENDSTax_Perc = 0 
replace ENDSTax_Perc = 13 if province == "BC" & year>=2020
replace ENDSTax_Perc = 20 if province == "NL" & year>=2021
replace ENDSTax_Perc = 10 if province == "NS" & (month==9 & year == 2020) 
replace ENDSTax_Perc = 20 if province == "NS" & ((month>9 & year == 2020) | year>2020)
replace ENDSTax_Perc = 20 if province == "SK" & ((month>=9 & year == 2021) | year>2021)

gen ENDSTax_PerML = 0 
replace ENDSTax_PerML = 25 if province == "NS" & month==9 & year == 2020
replace ENDSTax_PerML = 50 if province == "NS" & ((month>9 & year == 2020) | year>2020)

gen ecig_nicotine = 0
replace ecig_nicotine = 0.5 if province == "BC" & month == 9 & year == 2020
replace ecig_nicotine = 1 if (province=="BC" | province=="NS") & ((month>9 & year==2020) | year>=2021)
replace ecig_nicotine = 1 if province=="ON" & (year>=2021| (month>=7 & year == 2020))
replace ecig_nicotine = 1 if ((month>=7 & year==2021) | year>=2022)

gen trade_bubble = 0 
replace trade_bubble = 1 if province == "NS" & time>30 & time<36
replace trade_bubble = 1 if province == "NB" & time>30 & time<36
replace trade_bubble = 1 if province == "NL" & time>30 & time<36

gen ban_minor_sales = 1 
replace ban_minor_sales = 0 if province == "AB" & year == 2018 & month<6

drop if time>67
save google_analytic.dta, replace 

****************Figure 1 Stacked DD Event Studies - E-Cigarette Sales**************************
use analytic.dta, replace

local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id  `outcomes'  treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

sum units_per_capita if ttt<0 & ttt>-13
sum units_flavored_per_capita if ttt<0 & ttt>-13
sum units_tob_unflav_per_capita if ttt<0 & ttt>-13
sum units_mint_per_capita if ttt<0 & ttt>-13


**************Figure 1a*******************
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe log_units_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post
matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")],reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")] ,reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] ,  [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
*name the columns so they look correct on the x-axis
mat colnames A = "-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'(`se2')", pos(6) size(12pt))

graph export "Output\Figure_1a_Log_Units.pdf", as(pdf) name("Graph") replace

**************Figure 1b*******************
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)


local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe log_units_tob_unflav_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

//xlincom ((1.treat#1._Ievent_tim_25 + 1.treat#1._Ievent_tim_26 + 1.treat#1._Ievent_tim_27 + 1.treat#1._Ievent_tim_28 + 1.treat#1._Ievent_tim_29 + 1.treat#1._Ievent_tim_30)/6) 
//xlincom ((1.treat#1._Ievent_tim_31 + 1.treat#1._Ievent_tim_32 + 1.treat#1._Ievent_tim_33 + 1.treat#1._Ievent_tim_34 + 1.treat#1._Ievent_tim_35 + 1.treat#1._Ievent_tim_36+ 1.treat#1._Ievent_tim_37+ 1.treat#1._Ievent_tim_38+ 1.treat#1._Ievent_tim_39+ 1.treat#1._Ievent_tim_40+ 1.treat#1._Ievent_tim_41+ 1.treat#1._Ievent_tim_42+ 1.treat#1._Ievent_tim_43+ 1.treat#1._Ievent_tim_44+ 1.treat#1._Ievent_tim_45+ 1.treat#1._Ievent_tim_46+ 1.treat#1._Ievent_tim_47+ 1.treat#1._Ievent_tim_48+ 1.treat#1._Ievent_tim_49)/19) 

matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post

matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")],reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")] ,reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] ,  [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
*name the columns so they look correct on the x-axis
xlincom ((1.treat#1._Ievent_tim_22+ 1.treat#1._Ievent_tim_23 + 1.treat#1._Ievent_tim_24 + 1.treat#1._Ievent_tim_25 + 1.treat#1._Ievent_tim_26 + 1.treat#1._Ievent_tim_37)/6) 


mat colnames A = "-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'*(`se2')", pos(6) size(12pt))
graph export "Output\Figure_1b_Log_Units_Tobacco_Unflavored.pdf", as(pdf) name("Graph") replace

**************Figure 1c*******************
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe log_units_flavored_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post

matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")],reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")] ,reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] ,  [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
*name the columns so they look correct on the x-axis
mat colnames A = "-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) ylabel(-15(5)5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'***(`se2')", pos(6) size(12pt))
graph export "Output\Figure_1c_Log_Units_Flavored.pdf", as(pdf) name("Graph") replace

**************Figure 1d*******************
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe log_units_mint_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post

matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")],reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")] ,reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] ,  [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
*name the columns so they look correct on the x-axis
mat colnames A = "-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) ylabel(-15(5)5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'*(`se2')", pos(6) size(12pt))
graph export "Output\Figure_1d_Log_Units_Mint.pdf", as(pdf) name("Graph") replace


**********************Table 2 Column 1-4: E-Cigarette Results************************
eststo: reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)


est store results1_4

eststo: reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
est store results1_8

eststo: reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
est store results1_12

eststo: reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
est store results1_16

esttab results1_* using "Output\Table_2_e_cig_results.html", replace html label brackets cells(b(fmt(3) star) se(fmt(3) par)) stats(N , labels("N") fmt(%9.0fc %4.3f  ))  alignment(center) star(* 0.1 ** 0.05 *** 0.01) keep(ecig_flavor)

replace event_time= event_time + 22

egen panel_exp = group(sub_exp panel_id)

xtset panel_exp event_time

//Get wild bootstrap p-values 
wildboot xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp i.sub_exp#i.province_dum i.sub_exp#i.event_time [aw = stack_weight], fe cluster(panel_id) coef(ecig_flavor) reps(1000000) rseed(1000)

wildboot xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp i.sub_exp#i.province_dum i.sub_exp#i.event_time [aw = stack_weight], fe cluster(panel_id) coef(ecig_flavor) reps(1000000) rseed(1000)

wildboot xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp i.sub_exp#i.province_dum i.sub_exp#i.event_time [aw = stack_weight], fe cluster(panel_id) coef(ecig_flavor) reps(1000000) rseed(1000)

wildboot xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions  UnEmp i.sub_exp#i.province_dum i.sub_exp#i.event_time [aw = stack_weight], fe cluster(panel_id) coef(ecig_flavor) reps(1000000) rseed(1000)





**************Figure 2: Placebo Test*****************
clear
set more off

local kappa_pre  = 21
local kappa_post = 21

local outcomes ///
    log_units_per_capita ///
    log_units_flavored_per_capita ///
    log_units_tob_unflav_per_capita ///
    log_units_mint_per_capita

local controls ///
    cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble ///
    UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions


*===============================================================
* 1. Build actual stacked data once
*===============================================================

use analytic.dta, clear

gen first_time_treated = flavor_treat_period
gen time_id  = time
gen panel_id = province_dum

levelsof first_time_treated, local(alist)

foreach j of numlist `alist' {
    preserve
        create_sub_exp, ///
            timeID(time_id) ///
            groupID(panel_id) ///
            adoptionTime(first_time_treated) ///
            focalAdoptionTime(`j') ///
            kappa_pre(`kappa_pre') ///
            kappa_post(`kappa_post')
    restore
}

sum time_id
local minTime = r(min)
local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre'
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post'

sum feasible_year
local minadopt = r(min)

levelsof feasible_year, local(alist)

clear
foreach j of numlist `alist' {
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
    groupID(panel_id) ///
    subexpVar(sub_exp)

tempfile actual_stack
save `actual_stack', replace


*===============================================================
* 2. Generate province permutations
*===============================================================

use analytic.dta, clear
bysort province_dum: keep if _n == 1
keep province_dum
sort province_dum
mkmat province_dum, matrix(PROV)

local nprov = rowsof(PROV)
di "Unique provinces: `nprov'"

mata:
real scalar my_fact(real scalar n) {
    real scalar r, i
    r = 1
    for (i = 2; i <= n; i = i + 1) r = r * i
    return(r)
}

real matrix all_perms(real scalar n) {
    real matrix P
    real rowvector v, c
    real scalar i, tmp, idx

    P = J(my_fact(n), n, .)
    v = 1..n
    c = J(1, n, 0)

    P[1,.] = v
    idx = 2
    i = 1

    while (i <= n) {
        if (c[i] < i - 1) {
            if (mod(i, 2) == 1) {
                tmp = v[1]
                v[1] = v[i]
                v[i] = tmp
            }
            else {
                tmp = v[c[i] + 1]
                v[c[i] + 1] = v[i]
                v[i] = tmp
            }

            P[idx,.] = v
            idx = idx + 1
            c[i] = c[i] + 1
            i = 1
        }
        else {
            c[i] = 0
            i = i + 1
        }
    }

    return(P)
}

PERMS = all_perms(`nprov')
st_matrix("PERMS", PERMS)
end

local nperm = rowsof(PERMS)
di "Permutations to run: `nperm'"


*===============================================================
* 3. Loop over outcomes
*===============================================================

cap postclose SUM
postfile SUM str40 outcome double(actual_b actual_s actual_t pval_b pval_t n_placebos) ///
    using ri_summary_flavored.dta, replace

foreach y of local outcomes {

    di as text "=================================================="
    di as result "Running outcome: `y'"
    di as text "=================================================="

    use `actual_stack', clear

    reghdfe `y' ecig_flavor `controls' [aw = stack_weight], ///
        cluster(panel_id) ///
        absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

    local actual_b = _b[ecig_flavor]
    local actual_s = _se[ecig_flavor]
    local actual_t = `actual_b' / `actual_s'

    di as result "Actual beta = " %7.4f `actual_b' "  t = " %6.3f `actual_t'

    cap postclose PH
    postfile PH int iter double(beta se tstat) using placebo_results_`y'.dta, replace


    *===========================================================
    * Placebo loop
    *===========================================================

    forvalues r = 2/`nperm' {

        qui {

            use analytic.dta, clear

            preserve
                clear
                set obs `nprov'
                gen long j = _n
                gen long province_dum = .
                gen long source_province = .

                forvalues k = 1/`nprov' {
                    local src_idx = PERMS[`r', `k']
                    local tgt_p = PROV[`k', 1]
                    local src_p = PROV[`src_idx', 1]

                    replace province_dum = `tgt_p' if j == `k'
                    replace source_province = `src_p' if j == `k'
                }

                drop j
                tempfile pmap
                save `pmap', replace
            restore

            preserve
                keep province_dum time ecig_flavor flavor_treat_period
                rename province_dum source_province
                rename ecig_flavor _ecig_src
                rename flavor_treat_period _ftp_src
                tempfile src_treat
                save `src_treat', replace
            restore

            merge m:1 province_dum using `pmap', nogen
            merge m:1 source_province time using `src_treat', nogen keep(match master)

            replace ecig_flavor = _ecig_src
            replace flavor_treat_period = _ftp_src

            drop _ecig_src _ftp_src source_province

            cap drop first_time_treated time_id panel_id feasible_year
            gen first_time_treated = flavor_treat_period
            gen time_id = time
            gen panel_id = province_dum

            levelsof first_time_treated, local(alist)

            foreach j of numlist `alist' {
                preserve
                    create_sub_exp, ///
                        timeID(time_id) ///
                        groupID(panel_id) ///
                        adoptionTime(first_time_treated) ///
                        focalAdoptionTime(`j') ///
                        kappa_pre(`kappa_pre') ///
                        kappa_post(`kappa_post')
                restore
            }

            sum time_id
            local minTime = r(min)
            local maxTime = r(max)

            gen feasible_year = first_time_treated
            replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre'
            replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post'

            sum feasible_year
            local minadopt = r(min)

            levelsof feasible_year, local(alist)

            clear
            foreach j of numlist `alist' {
                if `j' == `minadopt' use temp/subexp`j', clear
                else append using temp/subexp`j'
            }

            compute_weights, ///
                treatedVar(treat) ///
                eventTimeVar(event_time) ///
                groupID(panel_id) ///
                subexpVar(sub_exp)

            cap reghdfe `y' ecig_flavor `controls' [aw = stack_weight], ///
                cluster(panel_id) ///
                absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

            if _rc == 0 & !missing(_se[ecig_flavor]) & _se[ecig_flavor] > 0 {
                local b = _b[ecig_flavor]
                local s = _se[ecig_flavor]
                post PH (`r') (`b') (`s') (`b' / `s')
            }
        }

        if mod(`r', 25) == 0 {
            noi di as txt "Outcome `y': done " `r' " / " `nperm'
        }
    }

    postclose PH


    *===========================================================
    * P-values and graphs
    *===========================================================

    use placebo_results_`y'.dta, clear

    local total = _N
    di as text "Successful placebos for `y': `total'"

	if `actual_b' < 0 {
		count if beta <= `actual_b'
		}
	else {
		count if beta >= `actual_b'
		}
	local n_extreme_b = r(N)
	local pval_b = `n_extreme_b' / `total'

    if `actual_t' < 0 {
    count if tstat <= `actual_t'
	}
	else {
    count if tstat >= `actual_t'
	}
	local n_extreme_t = r(N)
	local pval_t = `n_extreme_t' / `total'

    di as result "`y'"
    di as result "RI-beta p = " %7.4f `pval_b' "  
    di as result "RI-t    p = " %7.4f `pval_t' "

    post SUM ("`y'") (`actual_b') (`actual_s') (`actual_t') ///
        (`pval_b') (`pval_t') (`total')

    twoway (histogram beta, frequency fcolor(navy%40) lcolor(navy)), ///
        xline(`actual_b', lcolor(red) lwidth(medthick)) ///
        xtitle("Placebo coefficient") ///
		xlabel(,nogrid) ///
        ytitle("Frequency") ///
		note("Red line - actual coefficient (se): `: di %5.3f `actual_b'' (`: di %5.3f `actual_s'')" ///
     "RI-beta one-tailed p-value: `: di %5.3f `pval_b''", size(medium))
graph save "Output\Figure_2_placebo_beta_`y'.gph", replace
    

    twoway (histogram tstat, frequency fcolor(maroon%40) lcolor(maroon)), ///
        xline(`actual_t', lcolor(red) lwidth(medthick)) ///
        xtitle("Placebo t-stat") ///
		xlabel(,nogrid) ///
        ytitle("Frequency") ///
        note("Red line - actual t-stat: `: di %5.2f `actual_t''" ///
		"RI-t one-tailed p-value: `: di %5.3f `pval_t''", size(medium))
graph save "Output\placebo_tstat_`y'.gph", replace
    
}

postclose SUM

use ri_summary_flavored.dta, clear
list, clean


****************Figure 3a: Stacked DD Point Estimates- Cigarette and E-Cigarette Sales**************************
use analytic.dta, replace 

local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id  `outcomes'  treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

//Generate stack weights weighted by population
bysort event_time sub_exp treat: egen sub_exp_stack_weight = sum(stack_weight)
bysort event_time sub_exp treat: egen exp_arm_pop = sum(pop)
gen pop_stack_weight = sub_exp_stack_weight * pop/exp_arm_pop

gen specification = runiformint(0,11)

gen coef1 = . 
gen ci_upper1 = . 
gen ci_lower1 = . 

gen coef2 = . 
gen ci_upper2 = . 
gen ci_lower2 = .

reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 1
replace ci_lower1 = r(table)[5, 1] if specification == 1
replace ci_upper1 = r(table)[6, 1] if specification == 1


reghdfe lstand_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 2
replace ci_lower1 = r(table)[5, 1] if specification == 2
replace ci_upper1 = r(table)[6, 1] if specification == 2

reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if time<27 | time>32, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 3
replace ci_lower1 = r(table)[5, 1] if specification == 3
replace ci_upper1 = r(table)[6, 1] if specification == 3

reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = pop_stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 4
replace ci_lower1 = r(table)[5, 1] if specification == 4
replace ci_upper1 = r(table)[6, 1] if specification == 4


//Estimates from regressions in lines 783-791 of cigarette code
replace coef2 = .0920804 if specification == 6
replace ci_lower2 =  .021634 if specification == 6
replace ci_upper2 = .1625267 if specification == 6

replace coef2 = .0949334 if specification == 7
replace ci_lower2 = .0276403 if specification == 7
replace ci_upper2 = .1622266 if specification == 7

replace coef2 = .110759 if specification == 8
replace ci_lower2 =  .0033201 if specification == 8
replace ci_upper2 = .2181978 if specification == 8


duplicates drop specification, force


twoway ///
(scatter coef1 specification if inlist(specification, 1, 2, 3, 4, 5), msize(medium) msymbol(circle) color(navy)) ///
(rcap ci_lower1 ci_upper1 specification if inlist(specification, 1, 2, 3, 4, 5), color(navy) lwidth(medium)) ///
(scatter coef2 specification if inlist(specification, 6, 7, 8, 9), msize(medium) msymbol(triangle) color(maroon)) ///
(rcap ci_lower2 ci_upper2 specification if inlist(specification,6, 7, 8, 9), color(maroon) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "Standardized" 3 "Drop Mar.- Aug. 2020" 4 "Population Weighted" 6 "Baseline" 7 "Drop Mar.- Aug. 2020" 8 "Pop. Weighted (All Prov. & Terr.)" , angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("", size(small)) ///
yline(0, lcolor(black) lpattern(dash)) ///
scale(1.2) ///
xscale(range(0 7)) ///
legend(order(1 "ln(NVP Unit Sales/Capita)" 3 "ln(Cigarette Sales/Capita)") ///
       position(6) cols(2) region(style(none))) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_3a_Point_Estimates_Sales_log.pdf", as(pdf) name("Graph") replace


*************Figure 3b: Stacked DD Point Estimates*************
use analytic.dta, replace 

local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id  `outcomes'  treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 


//Generate stack weights weighted by population
bysort event_time sub_exp: egen sub_exp_stack_weight = sum(stack_weight)
bysort event_time sub_exp treat: egen exp_arm_pop = sum(pop)
gen pop_stack_weight = sub_exp_stack_weight * pop/exp_arm_pop

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

gen specification = runiformint(0,18)
gen coef1 = . 
gen ci_upper1 = . 
gen ci_lower1 = . 

gen coef2 = . 
gen ci_upper2 = . 
gen ci_lower2 = .

gen coef3 = . 
gen ci_upper3 = . 
gen ci_lower3 = .

reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 1
replace ci_lower1 = r(table)[5, 1] if specification == 1
replace ci_upper1 = r(table)[6, 1] if specification == 1

reghdfe lstand_units_flav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 2
replace ci_lower1 = r(table)[5, 1] if specification == 2
replace ci_upper1 = r(table)[6, 1] if specification == 2

reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if time<27 | time>32, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 3
replace ci_lower1 = r(table)[5, 1] if specification == 3
replace ci_upper1 = r(table)[6, 1] if specification == 3

reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = pop_stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef1     = r(table)[1, 1] if specification == 4
replace ci_lower1 = r(table)[5, 1] if specification == 4
replace ci_upper1 = r(table)[6, 1] if specification == 4


reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef2     = r(table)[1, 1] if specification == 6
replace ci_lower2 = r(table)[5, 1] if specification == 6
replace ci_upper2 = r(table)[6, 1] if specification == 6

reghdfe lstand_units_mint_per_capit ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef2     = r(table)[1, 1] if specification == 7
replace ci_lower2 = r(table)[5, 1] if specification == 7
replace ci_upper2 = r(table)[6, 1] if specification == 7

reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if time<27 | time>32, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef2     = r(table)[1, 1] if specification == 8
replace ci_lower2 = r(table)[5, 1] if specification == 8
replace ci_upper2 = r(table)[6, 1] if specification == 8

reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = pop_stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef2     = r(table)[1, 1] if specification == 9
replace ci_lower2 = r(table)[5, 1] if specification == 9
replace ci_upper2 = r(table)[6, 1] if specification == 9


reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef3     = r(table)[1, 1] if specification == 11
replace ci_lower3 = r(table)[5, 1] if specification == 11
replace ci_upper3 = r(table)[6, 1] if specification == 11

reghdfe lstand_units_unflav_per_capit ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef3     = r(table)[1, 1] if specification == 12
replace ci_lower3 = r(table)[5, 1] if specification == 12
replace ci_upper3 = r(table)[6, 1] if specification == 12

reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if time<27 | time>32, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef3     = r(table)[1, 1] if specification == 13
replace ci_lower3 = r(table)[5, 1] if specification == 13
replace ci_upper3 = r(table)[6, 1] if specification == 13

reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = pop_stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

replace coef3     = r(table)[1, 1] if specification == 14
replace ci_lower3 = r(table)[5, 1] if specification == 14
replace ci_upper3 = r(table)[6, 1] if specification == 14


duplicates drop specification, force

twoway ///
(scatter coef1 specification if inlist(specification, 1, 2, 3, 4), msize(medium) msymbol(circle) color(navy)) ///
(rcap ci_lower1 ci_upper1 specification if inlist(specification, 1, 2, 3, 4), color(navy) lwidth(medium)) ///
(scatter coef2 specification if inlist(specification, 6, 7, 8, 9), msize(medium) msymbol(triangle) color(green)) ///
(rcap ci_lower2 ci_upper2 specification if inlist(specification,6, 7, 8, 9), color(green) lwidth(medium)) ///
(scatter coef3 specification if inlist(specification, 11, 12, 13, 14, 15), msize(medium) msymbol(diamond) color(maroon)) ///
(rcap ci_lower3 ci_upper3 specification if inlist(specification, 11, 12, 13, 14, 15), color(maroon) lwidth(medium)), ///
xlabel( 1 "Baseline" 2 "Standardized" 3 "Drop March-Aug. 2020" 4 "Population Weighted" ///
		6 "Baseline" 7 "Standardized" 8 "Drop March-Aug. 2020" 9 "Population Weighted" ///
		11 "Baseline" 12 "Standardized" 13 "Drop March-Aug. 2020" 14 "Population Weighted", ///
        angle(28) labsize(small) nogrid) ///
ylabel(-10(2)2, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("", size(small)) ///
yline(0, lcolor(black) lpattern(dash)) ///
scale(1.2) ///
xscale(range(0 12)) ///
legend(order(1 "ln(Flavored Non-Mentholated Units/Capita)" 3 "ln(Mentholated Units/Capita)" 5 "ln(Tobacco & Unflavored Units/Capita)") ///
       position(6) cols(1) region(style(none))) ///
graphregion(margin(0 2 2 0))
graph export "Output\Figure_3b_Stacked_Point_Estimates_Flavors.pdf", as(pdf) name("Graph") replace

****************Figure 4a Stacked DD Point Estimates by Province**************************
use analytic.dta, replace 

local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id  `outcomes'  treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

gen specification = runiformint(0,13)
gen coef1 = . 
gen ci_upper1 = . 
gen ci_lower1 = . 

gen coef2 = . 
gen ci_upper2 = . 
gen ci_lower2 = .

//Baseline
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef1     = r(table)[1, 1] if specification == 1
replace ci_lower1 = r(table)[5, 1] if specification == 1
replace ci_upper1 = r(table)[6, 1] if specification == 1

//BC
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 33, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef1     = r(table)[1, 1] if specification == 2
replace ci_lower1 = r(table)[5, 1] if specification == 2
replace ci_upper1 = r(table)[6, 1] if specification == 2


//MB & SK
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 45, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef1     = r(table)[1, 1] if specification == 3
replace ci_lower1 = r(table)[5, 1] if specification == 3
replace ci_upper1 = r(table)[6, 1] if specification == 3

//Maritimes
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 28, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef1     = r(table)[1, 1] if specification == 4
replace ci_lower1 = r(table)[5, 1] if specification == 4
replace ci_upper1 = r(table)[6, 1] if specification == 4


//ON
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 31, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef1     = r(table)[1, 1] if specification == 5
replace ci_lower1 = r(table)[5, 1] if specification == 5
replace ci_upper1 = r(table)[6, 1] if specification == 5

//Estimates from regressions in lines 876-892 of cigarette code

//Baseline
replace coef2 =.0920804 if specification == 7
replace ci_lower2 = .021634 if specification == 7
replace ci_upper2 = .1625267 if specification == 7

//BC
replace coef2 = .1970445 if specification == 8
replace ci_lower2 = .1367987 if specification == 8
replace ci_upper2 = .2572903 if specification == 8


//SK
replace coef2 = .086989 if specification == 9
replace ci_lower2 = -.1102556 if specification == 9
replace ci_upper2 = .2842337 if specification == 9

//NB
replace coef2 = .075499 if specification == 10
replace ci_lower2 = -.0223005 if specification == 10
replace ci_upper2 = .1732986  if specification == 10

//NS
replace coef2 = .0022908 if specification == 11
replace ci_lower2 =-.0796048 if specification == 11
replace ci_upper2 = .0841864 if specification == 11

//ON
replace coef2 = .1720233 if specification == 12
replace ci_lower2 = .112685 if specification == 12
replace ci_upper2 = .2313615 if specification == 12

duplicates drop specification, force

twoway ///
(scatter coef1 specification if inlist(specification, 1, 2, 3, 4, 5), msize(medsmall) msymbol(circle) color(navy)) ///
(rcap ci_lower1 ci_upper1 specification if inlist(specification, 1, 2, 3, 4 , 5), color(navy) lwidth(medium)) ///
(scatter coef2 specification if inlist(specification, 7,8,9,10,11,12), msize(medsmall) msymbol(triangle) color(maroon)) ///
(rcap ci_lower2 ci_upper2 specification if inlist(specification, 7,8,9,10,11,12), color(maroon) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "British Columbia*" 3 "Manitoba & {bf:Saskatchewan}*^" 4 "Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 5 "Ontario*^" 7 "Baseline" 8 "British Columbia*" 9 "Saskatchewan*^" 10 "New Brunswick" 11"Nova Scotia" 12 "Ontario*^" , angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("", size(small)) ///
yline(0, lcolor(black) lpattern(dash)) ///
xscale(range(0 13)) ///
scale(1.2) ///
legend(order(1 "ln(NVP Unit Sales/Capita)" 3 "ln(Cigarette Sales/Capita)" ) ///
       position(6) cols(4) region(style(none))) ///
graphregion(margin(0 2 2 0))
graph export "Output\Figure_4a_Point_Estimates_By_Province.pdf", as(pdf) name("Graph") replace


****************Figure 4b Stacked DD Point Estimates by Province**************************
use analytic.dta, replace 

local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id  `outcomes'  treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

gen specification = runiformint(0,25)

gen coef2 = . 
gen ci_upper2 = . 
gen ci_lower2 = .

gen coef3 = . 
gen ci_upper3 = . 
gen ci_lower3 = .

gen coef4 = . 
gen ci_upper4 = . 
gen ci_lower4 = .


//Baseline
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef2     = r(table)[1, 1] if specification == 8
replace ci_lower2 = r(table)[5, 1] if specification == 8
replace ci_upper2 = r(table)[6, 1] if specification == 8

//BC
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 33, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef2     = r(table)[1, 1] if specification == 9
replace ci_lower2 = r(table)[5, 1] if specification == 9
replace ci_upper2 = r(table)[6, 1] if specification == 9


//MB & SK
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 45, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef2     = r(table)[1, 1] if specification == 10
replace ci_lower2 = r(table)[5, 1] if specification == 10
replace ci_upper2 = r(table)[6, 1] if specification == 10

//Maritimes
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 28, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef2     = r(table)[1, 1] if specification == 11
replace ci_lower2 = r(table)[5, 1] if specification == 11
replace ci_upper2 = r(table)[6, 1] if specification == 11


//ON
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 31, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef2     = r(table)[1, 1] if specification == 12
replace ci_lower2 = r(table)[5, 1] if specification == 12
replace ci_upper2 = r(table)[6, 1] if specification == 12

//Baseline
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef3     = r(table)[1, 1] if specification == 14
replace ci_lower3 = r(table)[5, 1] if specification == 14
replace ci_upper3 = r(table)[6, 1] if specification == 14

//BC
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 33, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef3     = r(table)[1, 1] if specification == 15
replace ci_lower3 = r(table)[5, 1] if specification == 15
replace ci_upper3 = r(table)[6, 1] if specification == 15


//MB & SK
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 45, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef3     = r(table)[1, 1] if specification == 16
replace ci_lower3 = r(table)[5, 1] if specification == 16
replace ci_upper3 = r(table)[6, 1] if specification == 16

//Maritimes
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 28, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef3     = r(table)[1, 1] if specification == 17
replace ci_lower3 = r(table)[5, 1] if specification == 17
replace ci_upper3 = r(table)[6, 1] if specification == 17


//ON
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 31, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef3     = r(table)[1, 1] if specification == 18
replace ci_lower3 = r(table)[5, 1] if specification == 18
replace ci_upper3 = r(table)[6, 1] if specification == 18

//Baseline
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef4     = r(table)[1, 1] if specification == 20
replace ci_lower4 = r(table)[5, 1] if specification == 20
replace ci_upper4 = r(table)[6, 1] if specification == 20

//BC
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 33, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef4     = r(table)[1, 1] if specification == 21
replace ci_lower4 = r(table)[5, 1] if specification == 21
replace ci_upper4 = r(table)[6, 1] if specification == 21


//MB & SK
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 45, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef4     = r(table)[1, 1] if specification == 22
replace ci_lower4 = r(table)[5, 1] if specification == 22
replace ci_upper4 = r(table)[6, 1] if specification == 22

//Maritimes
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 28, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef4     = r(table)[1, 1] if specification == 23
replace ci_lower4 = r(table)[5, 1] if specification == 23
replace ci_upper4 = r(table)[6, 1] if specification == 23


//ON
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight] if sub_exp == 31, cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
replace coef4     = r(table)[1, 1] if specification == 24
replace ci_lower4 = r(table)[5, 1] if specification == 24
replace ci_upper4 = r(table)[6, 1] if specification == 24

duplicates drop specification, force

twoway ///
(scatter coef2 specification if inlist(specification, 8,9,10,11,12), msize(medium) color(navy)) ///
(rcap ci_lower2 ci_upper2 specification if inlist(specification, 8,9,10,11,12), color(navy) lwidth(medium)) ///
(scatter coef3 specification if inlist(specification, 14,15,16,17,18), msize(medium) msymbol(triangle) color(green)) ///
(rcap ci_lower3 ci_upper3 specification if inlist(specification, 14,15,16,17,18), color(green) lwidth(medium)) ///
(scatter coef4 specification if inlist(specification, 20,21,22,23,24), msize(medium) msymbol(diamond) color(maroon)) ///
(rcap ci_lower4 ci_upper4 specification if inlist(specification, 20,21,22,23,24), color(maroon) lwidth(medium)), ///
xlabel( 8 "Baseline" 9 "British Columbia*" 10 "Manitoba & {bf:Saskatchewan}*^" 11 "Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 12 "Ontario*^"14 "Baseline" 15 "British Columbia*" 16 "Manitoba & {bf:Saskatchewan}*^" 17 "Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 18 "Ontario*^" 20 "Baseline" 21 "British Columbia*" 22 "Manitoba & {bf:Saskatchewan}*^" 23 "Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 24 "Ontario*^" , angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("", size(small)) ///
xscale(range(7 25)) ///
yline(0, lcolor(black) lpattern(dash)) ///
scale(1.2) ///
legend(order(1 "ln(Flavored Non-Mentholated Units/Capita)" 3 "ln(Mentholated Units/Capita)" 5 "ln(Tobacco & Unflavored Units/Capita)") ///
       position(6) cols(1) region(style(none))) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_4b_Stacked_Point_Estimates_Flavors_By_Province.pdf", as(pdf) name("Graph") replace



*****************Figure 6: Stacked Google Trends************************
use google_analytic, replace 
gen log_shopping = ln(shopping)
gen log_interest = ln(interest)
local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

egen pid = group(province_dum sub_exp)

xtset pid event_time

replace event_time = event_time + 30

wildboot xtreg log_shopping ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.province_dum i.sub_exp#i.event_time [aw = stack_weight], fe cluster(panel_id) coef(ecig_flavor) reps(1000000) rseed(1000)

reghdfe log_shopping ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe log_shopping cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
matrix reg1=r(table)

//eststo A1: xlincom ((1.treat#1._Ievent_tim_27 + 1.treat#1._Ievent_tim_28 + 1.treat#1._Ievent_tim_29 + 1.treat#1._Ievent_tim_30 + 1.treat#1._Ievent_tim_31 + 1.treat#1._Ievent_tim_32 + 1.treat#1._Ievent_tim_33 + 1.treat#1._Ievent_tim_34 + 1.treat#1._Ievent_tim_35 + 1.treat#1._Ievent_tim_36 + 1.treat#1._Ievent_tim_37+ 1.treat#1._Ievent_tim_38+ 1.treat#1._Ievent_tim_39+ 1.treat#1._Ievent_tim_40+ 1.treat#1._Ievent_tim_41+ 1.treat#1._Ievent_tim_42+ 1.treat#1._Ievent_tim_43+ 1.treat#1._Ievent_tim_44+ 1.treat#1._Ievent_tim_45+ 1.treat#1._Ievent_tim_46+ 1.treat#1._Ievent_tim_47+ 1.treat#1._Ievent_tim_48+ 1.treat#1._Ievent_tim_49+ 1.treat#1._Ievent_tim_50+ 1.treat#1._Ievent_tim_51+ 1.treat#1._Ievent_tim_52)/26), post 

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post

matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")] , reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")],reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] ,  [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
//matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")]
*name the columns so they look correct on the x-axis
mat colnames A = "-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"
*generate and save the event study
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel( 2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'**(`se2')", pos(6) size(12pt))

graph export "Output\Figure_6a_Stacked_Log_Shopping.pdf", as(pdf) name("Graph") replace

reghdfe log_interest ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe log_interest cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post

matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")] , reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")],reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] ,  [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
//matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")]
*name the columns so they look correct on the x-axis
mat colnames A = "-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

*generate and save the event study
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel( 2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'(`se2')", pos(6) size(12pt))
graph export "Output\Figure_6b_Stacked_Log_interest.pdf", as(pdf) name("Graph") replace


******************Table 1: E-Cigarette Summary Statistics********************
use analytic.dta, replace 
drop if year == 2018 & month<7 
drop if year == 2023 & month>6

sort time

gen First12M = 0
gen Last12M = 0 
gen treatment = 0 

replace First12M = 1 if time>6 & time<19
replace Last12M = 1 if time>54 & time<67
replace treatment = 1 if flavor_treat_period != .

eststo full: estpost summarize units_per_capita units_flavored_per_capita units_tob_unflav_per_capita units_mint_per_capita 

eststo pre_control: estpost summarize units_per_capita units_flavored_per_capita units_tob_unflav_per_capita units_mint_per_capita if treatment == 0 & First12M == 1

eststo post_control: estpost summarize units_per_capita units_flavored_per_capita units_tob_unflav_per_capita units_mint_per_capita if treatment == 0  & Last12M ==1 

eststo pre_treated: estpost summarize units_per_capita units_flavored_per_capita units_tob_unflav_per_capita units_mint_per_capita if treatment == 1  & First12M == 1

eststo post_treated: estpost summarize units_per_capita units_flavored_per_capita units_tob_unflav_per_capita units_mint_per_capita if treatment == 1  &  Last12M ==1 

* Export both to one file

esttab full pre_control post_control pre_treated post_treated using "Output\summary_stats_NVPS.html", ///
    replace html ///
    cells("mean(fmt(4)) sd(fmt(4)) N(fmt(0))") ///
    label
	
keep if First12M == 1 | Last12M == 1

//NVP Unit Sales DID estimates
regress units_per_capita i.Last12M i.treatment	i.Last12M#i.treatment, cluster(province_dum)
regress units_flavored_per_capita i.Last12M i.treatment	i.Last12M#i.treatment, cluster(province_dum)
regress units_tob_unflav_per_capita i.Last12M i.treatment	i.Last12M#i.treatment, cluster(province_dum)
regress units_mint_per_capita i.Last12M i.treatment	i.Last12M#i.treatment, cluster(province_dum)


//Google Trends summary statistics
use google_analytic.dta, replace 
drop if year == 2018 & month<7 
drop if year == 2023 & month>6

sort time

gen First12M = 0
gen Last12M = 0 
gen treatment = 0 

replace First12M = 1 if time>6 & time<19
replace Last12M = 1 if time>54 & time<67
replace treatment = 1 if flavor_treat_period != .

eststo full: estpost summarize shopping interest
eststo pre_control: estpost summarize shopping interest if treatment == 0 & First12M == 1
eststo post_control: estpost summarize shopping interest if treatment == 0  & Last12M ==1 
eststo pre_treated: estpost summarize shopping interest if treatment == 1  & First12M == 1
eststo post_treated: estpost summarize shopping interest if treatment == 1  &  Last12M ==1 
esttab full pre_control post_control pre_treated post_treated using "Output\summary_stats_google.html", ///
    replace html ///
    cells("mean(fmt(1)) sd(fmt(1)) N(fmt(0))") ///
    label

keep if First12M == 1 | Last12M == 1

//Google Trends DID Estimates
regress shopping i.Last12M i.treatment	i.Last12M#i.treatment
regress interest i.Last12M i.treatment	i.Last12M#i.treatment


****************Table 3: Alternate Models**************************
use analytic.dta, replace 
drop if year == 2018 & month<7 
drop if year == 2023 & month>6

//TWFE
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions, cluster(province_dum) absorb(i.province_dum i.time)
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions, cluster(province_dum) absorb(i.province_dum i.time)
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions, cluster(province_dum) absorb(i.province_dum i.time)
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions, cluster(province_dum) absorb(i.province_dum i.time)


xtset province_dum time
//Wild boot TWFE
wildboot xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, fe cluster(province_dum) coef(ecig_flavor) reps(1000000) rseed(1000)
wildboot xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, fe cluster(province_dum) coef(ecig_flavor) reps(1000000) rseed(1000)
wildboot xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, fe cluster(province_dum) coef(ecig_flavor) reps(1000000) rseed(1000)
wildboot xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, fe cluster(province_dum) coef(ecig_flavor) reps(1000000) rseed(1000)


//SDID
replace ecig_flavor = 1 if ecig_flavor>0
sdid log_units_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(1000) seed(10)
sdid log_units_flavored_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(1000) seed(10)
sdid log_units_tob_unflav_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(1000) seed(10)
sdid log_units_mint_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(1000) seed(10)

use analytic.dta, replace 

local kappa_pre = 21
local kappa_post= 21

gen first_time_treated = flavor_treat_period
gen time_id = time
gen panel_id = province_dum
levelsof first_time_treated, local(alist)
di "`alist'"

qui{
// Loop over the events and make a data set for each one
foreach j of numlist `alist' { 
  // Preserve dataset
  preserve

  // run function
  create_sub_exp, ///
    timeID(time_id) ///
    groupID(panel_id) ///
    adoptionTime(first_time_treated) ///
    focalAdoptionTime(`j') ///
    kappa_pre(`kappa_pre') ///
    kappa_post(`kappa_post')

  // restore dataset
  restore
}

// Append the stacks together, but only from feasible stacks
        * Determine earliest and latest time in the data. 
            * Used for feasibility check later
          sum time_id
          local minTime = r(min)
          local maxTime = r(max)

gen feasible_year = first_time_treated
replace feasible_year = . if first_time_treated < `minTime' + `kappa_pre' 
replace feasible_year = . if first_time_treated > `maxTime' - `kappa_post' 
sum feasible_year

local minadopt = r(min)
levelsof feasible_year, local(alist)
clear
foreach j of numlist `alist'  {
    display `j'
    if `j' == `minadopt' use temp/subexp`j', clear
    else append using temp/subexp`j'
}
}

* Summarize
sum panel_id time_id  `outcomes'  treat  post event_time feasible sub_exp

* Treated, control, and total count by stack
preserve
keep if event_time == 0
gen N_treated = treat 
gen N_control = 1 - treat 
gen N_total = 1
collapse (sum) N_treated N_control N_total, by(sub_exp)
list sub_exp N_treated N_control N_total 

restore

compute_weights, ///
    treatedVar(treat) ///
    eventTimeVar(event_time) ///
  groupID(panel_id) ///
    subexpVar(sub_exp) 

* Summarize 
sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean) 

// Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time


//Baseline
reghdfe log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
reghdfe log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
reghdfe log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
reghdfe log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)


//Stacked - Levels
reghdfe units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
sum units_per_capita if ttt_flavor<0 & ttt_flavor>-13

reghdfe units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
sum units_flavored_per_capita if ttt_flavor<0 & ttt_flavor>-13

reghdfe units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
sum units_tob_unflav_per_capita if ttt_flavor<0 & ttt_flavor>-13

reghdfe units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.province_dum i.sub_exp#i.event_time)
sum units_mint_per_capita if ttt_flavor<0 & ttt_flavor>-13



**********Figure A2: NVP Sales Trends for Treatment and Control Groups************
use analytic.dta, replace 
drop if year == 2018 & month<7 
drop if year == 2023 & month>6
gen treated = 0 
replace treated = 1 if ttt_flavor != . 

collapse (mean) units_per_capita units_flavored_per_capita units_mint_per_capita units_tob_unflav_per_capita, by(ym month year treated)

gen time = ym 

twoway (line units_per_capita ym if treated == 1, color(maroon))(line units_per_capita ym if treated == 0,  color(navy)lpattern(longdash)), legend(order(1 "Treatment Provinces" 2 "Control Provinces") pos(6) cols(2)) xline(722.5 725.5 727.5 733.5 739.5) ytitle("NVP Units per Capita") xtitle("") text(0.06 722.3  "NS" 0.06 725.3  "ON" 0.06 727.4  "BC" 0.06 733.3 "PEI" 0.055 739.4 "NB & SK", place(left) color(black) size(small)) xlabel(,nogrid) ylabel(0(0.01)0.06)
graph export "Output\Sales_Trends_Units.pdf", as(pdf) name("Graph") replace

twoway (line units_flavored_per_capita ym if treated == 1, color(maroon))(line units_flavored_per_capita ym if treated == 0,  color(navy)lpattern(longdash)), legend(order(1 "Treatment Provinces" 2 "Control Provinces") pos(6) cols(2)) xline(722.5 725.5 727.5 733.5 739.5) ytitle("NVP Units per Capita") xtitle("") ylabel(0(0.01)0.06) text(0.04 722.3  "NS" 0.04 725.3  "ON" 0.04 727.4  "BC" 0.04 733.3 "PEI" 0.04 739.4  "NB & SK", place(left) color(black) size(small)) xlabel(,nogrid)
graph export "Output\Sales_Trends_Units_Flavored.pdf", as(pdf) name("Graph") replace

twoway (line units_tob_unflav_per_capita ym if treated == 1, color(maroon))(line units_tob_unflav_per_capita ym if treated == 0,  color(navy)lpattern(longdash)), legend(order(1 "Treatment Provinces" 2 "Control Provinces") pos(6) cols(2)) xline(722.5 725.5 727.5 733.5 739.5) ytitle("NVP Units per Capita") xtitle("") text(0.03 722.3  "NS" 0.03 725.3  "ON" 0.03 727.4  "BC" 0.03 733.3 "PEI" 0.03 739.4  "NB & SK", place(left) color(black) size(small)) ylabel(0(0.01)0.06) xlabel(,nogrid)
graph export "Output\Sales_Trends_Units_Tobacco_Unflavored.pdf", as(pdf) name("Graph") replace

twoway (line units_mint_per_capita ym if treated == 1, color(maroon))(line units_mint_per_capita ym if treated == 0,  color(navy)lpattern(longdash)), legend(order(1 "Treatment Provinces" 2 "Control Provinces") pos(6) cols(2)) xline(722.5 725.5 727.5 733.5 739.5) ytitle("NVP Units per Capita") xtitle("") text(0.03 722.3  "NS" 0.03 725.3  "ON" 0.03 727.4  "BC" 0.03 733.3 "PEI" 0.03 739.4  "NB & SK", place(left) color(black) size(small)) ylabel(0(0.01)0.06) xlabel(,nogrid)
graph export "Output\Sales_Trends_Units_Mint.pdf", as(pdf) name("Graph") replace

log close


