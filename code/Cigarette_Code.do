cd "C:\Users\badhhh\OneDrive - University of Missouri\Projects\Canadian Flavor Ban\Code"

//log using cigarette_code.log, replace
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
        gen event_time = YM - sub_exp
        
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


*COVID19 deaths
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

browse YM date TotDeathsPriorMonth numdeaths Avgdeaths_last7 prname if YM>=tm(2023May) & (prname=="Prince Edward Island" | prname=="Newfoundland and Labrador"   | prname=="New Brunswick" | prname=="Nova Scotia")
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
keep prname TotDeathsPriorMonth YM newid    
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

save "MonthlyCovidCasesCanada.dta", replace

*Unemployment Rate - https://www.stats.gov.nl.ca/Statistics/Topics/labour/PDF/UnempRate_Monthly.pdf (webarchive)
import excel "Data\UnempRate_Monthly.xlsx", sheet("Stata") firstrow clear
foreach P in Alberta BritishColumbia Canada  NewBrunswick Manitoba NewfoundlandandLabrador NovaScotia Ontario PrinceEdwardIsland Quebec Saskatchewan {
	rename `P' UnEmp`P'
}
reshape long UnEmp, i(Date) j(Province) str
gen Prov="BC" if Province=="BritishColumbia"
	replace Prov="NB" if Province=="NewBrunswick"
	replace Prov="MB" if Province=="Manitoba"
	replace Prov="NF" if Province=="NewfoundlandandLabrador"
	replace Prov="NS" if Province=="NovaScotia"
	replace Prov="ON" if Province=="Ontario"
	replace Prov="PE" if Province=="PrinceEdwardIsland"
	replace Prov="QC" if Province=="Quebec"
	replace Prov="AB" if Province=="Alberta"
	replace Prov="Tot" if Province=="Canada"
	replace Prov="SK" if Province=="Saskatchewan"
	replace Prov="NB" if Province=="NewBrunswick"
split Date, parse("-") gen(Month)
rename Month2 Year
destring Year, replace
replace Year=2000+Year	
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
gen YM=ym(Year,Month)
format YM %tm	
keep YM UnEmp Prov 
save MonthlyUnempUnadjCanada.dta, replace


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
//drop Year Month

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
save CanadaCovidPolicies.dta, replace


foreach X in CovidRestrictionIndex InternalMvmtRestrictions NonEssRetRestrictions SchoolClosing  WorkplaceClosing {
	gen `X'_2022=`X' if Year==2022
	by Province, sort: egen Max2022_`X'=max(`X'_2022)
}

*Sales Data
forvalues x=2013(1)2017 {
	import excel "Data\Abigail_Friedman_Cigarette_Volume_Province_Month (II).xlsx", sheet(`x') firstrow clear
	rename A Months
	rename GrandTotal Tot
	foreach Y in AB BC MB NB NF NS NT NU ON PE QC SK YT Tot {
		rename `Y' CigsSales_`Y'
	}	
	reshape long CigsSales_, i(Months) j(Prov) string
	rename CigsSales_ CigsSales
	keep if Months!=""
	gen Year=`x'
	save "temp\CigsSales`x'.dta", replace
	clear
}


	import excel "Data\Abigail_Friedman_Cigarette_Volume_Province_Month (II).xlsx", sheet("2023 Half-Year") firstrow clear
	rename A Months
	rename GrandTotal Tot
	foreach Y in AB BC MB NB NF NS NT NU ON PE QC SK YT Tot {
		rename `Y' CigsSales_`Y'
	}	
	reshape long CigsSales_, i(Months) j(Prov) string
	rename CigsSales_ CigsSales
	keep if Months!=""
	gen Year=2023
	save "temp\CigsSales2023.dta", replace

clear
forvalues x=2018(1)2022 {
	import excel "Data\Abigail_Friedman_Cigarette_Volume_Province_Month.xlsx", sheet(`x') firstrow clear
	rename A Months
	rename GrandTotal Tot
	foreach Y in AB BC MB NB NF NS NT NU ON PE QC SK YT Tot {
		rename `Y' CigsSales_`Y'
	}	
	reshape long CigsSales_, i(Months) j(Prov) string
	rename CigsSales_ CigsSales
	keep if Months!=""
	gen Year=`x'
	save "temp\CigsSales`x'.dta", replace
	clear
}

use "temp\CigsSales2022.dta", replace
append using "temp\CigsSales2021.dta" "temp\CigsSales2020.dta" "temp\CigsSales2019.dta" "temp\CigsSales2018.dta" "temp\CigsSales2017.dta" "temp\CigsSales2016.dta" "temp\CigsSales2015.dta" "temp\CigsSales2014.dta" "temp\CigsSales2013.dta" "temp\CigsSales2023", gen(AppendSource)
gen M=1 if Months=="January"
	replace M=2 if Months=="February"
	replace M=3 if Months=="March"
	replace M=4 if Months=="April"
	replace M=5 if Months=="May"
	replace M=6 if Months=="June"
	replace M=7 if Months=="July"
	replace M=8 if Months=="August"
	replace M=9 if Months=="September"
	replace M=10 if Months=="October"
	replace M=11 if Months=="November"
	replace M=12 if Months=="December"
	replace M=. if Months=="Total"	
* Ban the sale of any e-liquid other than tobacco flavour.
gen FlvBanDate=td(01April2020) if Prov=="NS"
	replace FlvBanDate=td(01March2021) if Prov=="PE"
	replace FlvBanDate=td(01Sept2021) if Prov=="NB"
	replace FlvBanDate=td(25March2022) if Prov=="NT"
	replace FlvBanDate=td(31May2023) if Prov=="NU"
* Three Canadian provinces have adopted regulations to restrict the sale of flavoured vaping liquids to specialty vape shops where children are not permitted to enter. 
gen FlvRestDate=td(01Sept2020) if Prov=="BC"
	replace FlvRestDate=td(01July2020) if Prov=="ON"
	replace FlvRestDate=td(01Sept2021) if Prov=="SK" 
gen date=mdy(M,1,Year)
	format date FlvRestDate FlvBanDate %td
gen FlvRest=(date>=FlvRestDate & FlvRestDate!=.) if date!=.
gen FlvBan=(date>=FlvBanDate & FlvBanDate!=.) if date!=.

gen FlvRest365=(date>=(FlvRestDate+365) & FlvRestDate!=.) if date!=.
gen FlvBan365=(date>=(FlvBanDate+365) & FlvBanDate!=.) if date!=.
	format FlvRest FlvBan  FlvRest365 FlvBan365 %td
	assert FlvRest==0 if FlvRestDate==. & M!=.
	assert FlvBan==0 if FlvBanDate==.  & M!=.
	assert date==. & FlvBan==. & FlvRest==. if M==.
	egen newid = group(Prov)

*https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710000901 Q3 2022
gen Pop2022=525972 if Prov=="NF"
	replace Pop2022=4543111 if Prov=="AB"
	replace Pop2022=5319324 if Prov=="BC"
	replace Pop2022=1409223 if Prov=="MB"
	replace Pop2022=812061 if Prov=="NB"
	replace Pop2022=170688 if Prov=="PE"
	replace Pop2022=1019725 if Prov=="NS"
	replace Pop2022=8695659 if Prov=="QC"
	replace Pop2022=15109416 if Prov=="ON"
	replace Pop2022=1194803 if Prov=="SK"	
	replace Pop2022=43789 if Prov=="YT"
	replace Pop2022=45605 if Prov=="NT"
	replace Pop2022=40526 if Prov=="NU"
gen CigsPC=CigsSales/Pop2022
gen Flv=(FlvRest==1 | FlvBan==1) if date!=.
save CanadaCigSales_011923.dta, replace

gen CigTax=20 if Prov=="AB" & date>=td(8April2009) & date<td(27March2015)
	replace CigTax=22.5 if Prov=="AB" & date>=td(27March2015) & date<td(28Oct2015)
	replace CigTax=25 if Prov=="AB" & date>=td(28Oct2015) & date<td(25Oct2019)
	replace CigTax=27.5 if Prov=="AB" & date>=td(25Oct2019)	 	
	replace CigTax=21.3 if Prov=="BC" & date>=td(1Apr2013) & date<td(13Oct2013)
	replace CigTax=22.3 if Prov=="BC" & date>=td(13Oct2013) & date<td(01April2014)
	replace CigTax=23.9 if Prov=="BC" & date>=td(01April2014) & date<td(01Oct2017)
	replace CigTax=24.7 if Prov=="BC" & date>=td(01Oct2017) & date<td(01April2018)
	replace CigTax=27.5 if Prov=="BC" & date>=td(01April2018) & date<td(01Aug2020)
	replace CigTax=29.5 if Prov=="BC" & date>=td(01Aug2020) & date<td(01July2021)
	replace CigTax=32.5 if Prov=="BC" & date>=td(01July2021)	 	
	replace CigTax=29 if Prov=="MB" & date>=td(16April2013) & date<td(30April2015)
	replace CigTax=29.5 if Prov=="MB" & date>=td(30April2015) & date<td(30June2019)
	replace CigTax=30 if Prov=="MB" & date>=td(30June2019)	 	
	replace CigTax=19 if Prov=="NB" & date>=td(01July2013) & date<td(03Feb2016)
	replace CigTax=22.26 if Prov=="NB" & date>=td(03Feb2016) & date<td(01Feb2017)
	replace CigTax=25.52 if Prov=="NB" & date>=td(01Feb2017)	 	
	replace CigTax=20.5 if Prov=="NF" & date>=td(27March2013) & date<td(28March2014)
	replace CigTax=23.5 if Prov=="NF" & date>=td(28March2014) & date<td(15April2016)
	replace CigTax=24.5 if Prov=="NF" & date>=td(15April2016) & date<td(01Oct2020)
	replace CigTax=29.5 if Prov=="NF" & date>=td(01Oct2020) & date<td(01jun2021)
	replace CigTax=32.5 if Prov=="NF" & date>=td(01jun2021)	 	
	replace CigTax=23.52 if Prov=="NS" & date>=td(5April2013) & date<td(10April2015)
	replace CigTax=25.52 if Prov=="NS" & date>=td(10April2015) & date<td(20April2016)
	replace CigTax=27.52 if Prov=="NS" & date>=td(20April2016) & date<td(26-Feb2020)
	replace CigTax=29.52 if Prov=="NS" & date>=td(26Feb2020)	
	replace CigTax=12.35 if Prov=="ON" & date>=td(27March2013) & date<td(02May2014)
	replace CigTax=13.975 if Prov=="ON" & date>=td(02May2014) & date<td(26Feb2016)
	replace CigTax=15.475 if Prov=="ON" & date>=td(26Feb2016) & date<td(28April2017)
	replace CigTax=16.475 if Prov=="ON" & date>=td(28April2017) & date<td(29March2018)
	replace CigTax=18.475 if Prov=="ON" & date>=td(29March2018)	 	 
	replace CigTax=14.7 if Prov=="QC" & date>=td(21Nov2012) & date<td(04May2014) //HealthCanada says 5/4/14. Review doc says 6/5/14.
	replace CigTax=14.9 if Prov=="QC" & date>=td(04May2014) & date<td(09Feb2023)
	replace CigTax=18.9 if Prov=="QC" & date>=td(09Feb2023)	 	
	replace CigTax=25 if Prov=="SK" & date>=td(21March2013) & date<td(27March2017)
	replace CigTax=27 if Prov=="SK" & date>=td(27March2017) & date<td(24March2022)
	replace CigTax=29 if Prov=="SK" & date>=td(24March2022)	 
	replace CigTax=28.6 if Prov=="NT" & date>=td(01Feb2014) & date<td(01April2017)
	replace CigTax=30.4 if Prov=="NT" & date>=td(01April2017) & date<td(01Aug2022)
	replace CigTax=34.4 if Prov=="NT" & date>=td(01Aug2022)	 	
	replace CigTax=25 if Prov=="NU" & date>=td(23Feb2012) & date<td(15March2017)
	replace CigTax=30 if Prov=="NU" & date>=td(15March2017)	 	
	replace CigTax=22.5 if Prov=="PE" & date>=td(01April2013) & date<td(20June2015)
	replace CigTax=25 if Prov=="PE" & date>=td(20June2015) & date<td(15July2020)
	replace CigTax=27.52 if Prov=="PE" & date>=td(15July2020) & date<td(07May2022)
	replace CigTax=29.52 if Prov=="PE" & date>=td(07May2022)	 	
	replace CigTax=21 if Prov=="YT" & date>=td(01July2008) & date<td(01July2017)
	replace CigTax=25 if Prov=="YT" & date>=td(01July2017) & date<td(01April2018)
	replace CigTax=30 if Prov=="YT" & date>=td(01April2018) & date<td(01jan2021)
	replace CigTax=31 if Prov=="YT" & date>=td(01jan2021) & date<td(01jan2023)
	replace CigTax=32 if Prov=="YT" & date>=td(01jan2023)			
	label var CigTax "Cigarette Tax in cents/stick"
	gen YM=ym(Year,M)
	drop if Months=="Total" | Prov=="Tot"
	
gen EvFlvBanENDS=(Prov=="NS" | Prov=="PE" | Prov=="NB" | Prov=="NT" |  Prov=="NU")
gen EvFlvRestENDS=(Prov=="BC" | Prov=="ON" | Prov=="SK" )
	 
*https://globalnews.ca/news/10078342/vaping-taxes-canada/	 
gen ENDSTax_Perc=0
	replace ENDSTax_Perc=20-7 if Prov=="BC" & date>=td(01jan2020)  
	replace ENDSTax_Perc=20 if Prov=="NF" & date>=td(01jan2021)  
	*replace ENDSTax_Perc=7 if Prov=="BC" & date<td(01jan2021) <--suspect this is the provincial tax rate 
	replace ENDSTax_Perc=20 if Prov=="NS" & date>=td(15sept2020)   
	replace ENDSTax_Perc=20 if Prov=="SK" & date>=td(01sept2021)
gen ENDSTax_PerML=0
	replace ENDSTax_PerML=50 if Prov=="NS" & date>td(15sept2020)  
*BC framed as increasing from sales tax of 7% to 20% for vaping products
*Vaping products in N.S. are also subject to a 15 per cent harmonized sales tax (HST), which is a 10 per cent provincial value-added tax and a five per cent federal goods and services tax.
*N&L - "these products are subject to a 15 per cent harmonized sales tax (five per cent federal, 10 per cent provincial)."
*In Saskatchewan, a 20 per cent vapour product tax (VPT) on the sale of all vapour liquids, products and devices has been in effect since September 2021. These products are not currently subject to the provincial sales tax (PST), according to Saskatchewan's Ministry of Finance.
format YM %tm
gen ENDSFlvPol=(FlvRest==1 | FlvBan==1)
gen TerrPE=(Prov=="YT" | Prov=="NT" | Prov=="NU")
rename TerrPE Territories

merge 1:1 Prov YM using CanadaCovidPolicies.dta 
assert Year<2020 | Year==2023 if _merge==1
replace InternalMvmtRestrictions=0 if Year<2020
replace NonEssRetRestrictions=0 if Year<2020
replace SchoolClosing=0 if Year<2020
replace WorkplaceClosing=0 if Year<2020
assert InternalMvmtRestrictions==0 &  NonEssRetRestrictions==0 &  WorkplaceClosing==0 if (M==5 | M==6 | M==7 ) & Year==2022  
assert InternalMvmtRestrictions==. &  NonEssRetRestrictions==. &  WorkplaceClosing==. if M>7 & Year==2022  

replace InternalMvmtRestrictions=0 if (M>7 & Year==2022) | Year==2023
replace NonEssRetRestrictions=0 if (M>7 & Year==2022) | Year==2023
replace WorkplaceClosing=0 if (M>7 & Year==2022) | Year==2023 

* Canadian Cancer Society Overview summary of federal/provincial/territorial tobacco control legislation in Canada, 2017. Available: http://convio.cancer.ca/documents/Legislative_Overview-Tobacco_Control-F-P-T-2017-final.pdf
*https://tobaccocontrol.bmj.com/content/32/6/734

*implementation dates for bans on menthol cigarettes:
	*1. Nova Scotia (May 31, 2015)
	*2. Alberta (Sept. 30, 2015)
	*3. New Brunswick (Jan. 1, 2016)
	*4. Quebec (Aug. 26, 2016)
	*5. Ontario (Jan. 1, 2017)
	*6. Prince Edward Island (May 1, 2017)
	*7. Newfoundland and Labrador (July 1, 2017)
	*8. Federal (Oct. 2, 2017)

gen ProvMentholCigBanDate=td(31May2015) if Prov=="NS"
	replace ProvMentholCigBanDate=td(30Sept2015) if Prov=="AB" 
	replace ProvMentholCigBanDate=td(1Jan2016) if Prov=="NB" 
	replace ProvMentholCigBanDate=td(26Aug2016) if Prov=="QC" 
	replace ProvMentholCigBanDate=td(1Jan2017) if Prov=="ON" 
	replace ProvMentholCigBanDate=td(1May2017) if Prov=="PE" 
	replace ProvMentholCigBanDate=td(1July2017) if Prov=="NF"  
	replace ProvMentholCigBanDate=td(2Oct2017) if ProvMentholCigBanDate==. 
	format ProvMentholCigBanDate %td
gen FirstOfMonth=mdy(M,1,Year)
	gen MentholCigBan=(YM>tm(2017Oct))
	replace MentholCigBan=1 if YM>tm(2017July) & Prov=="NF"  
	replace MentholCigBan=1 if YM>tm(2017May) & Prov=="PE" 
	replace MentholCigBan=1 if YM>tm(2017Jan) & Prov=="ON" 
	replace MentholCigBan=1 if YM>tm(2016Sept) & Prov=="QC" 
	replace MentholCigBan=1 if YM>tm(2016Jan) & Prov=="NB" 
	replace MentholCigBan=1 if YM>=tm(2015Oct) & Prov=="AB" 
	replace MentholCigBan=1 if YM>=tm(2015June) & Prov=="NS" 

gen BanVapingSalesToMinors=(YM>tm(2018May))
	replace BanVapingSalesToMinors=1 if YM>tm(2015May) & Prov=="NS"
	replace BanVapingSalesToMinors=1 if YM>=tm(2015July) & Prov=="NB"
	replace BanVapingSalesToMinors=1 if YM>=tm(2015Oct) & Prov=="PE"
	replace BanVapingSalesToMinors=1 if YM>tm(2015Nov) & Prov=="QC"
	replace BanVapingSalesToMinors=1 if YM>=tm(2016Jan) & Prov=="ON"
	replace BanVapingSalesToMinors=1 if YM>tm(2016June) & Prov=="NF"
	replace BanVapingSalesToMinors=1 if YM>=tm(2016Sept) & Prov=="BC"
	replace BanVapingSalesToMinors=1 if YM>=tm(2017Oct) & Prov=="MB"
	
gen AtlBubble=(Prov=="NB" | Prov=="PE" | Prov=="NS" | Prov=="NF" )
egen GVAR=csgvar(ENDSFlvPol), tvar(YM) ivar(newid)

drop _merge
merge 1:1 Prov YM using  MonthlyUnempUnadjCanada.dta 
drop if YM>=tm(2023-July)

//assert Territories==1 if _merge==1
//assert Prov=="Tot"  if _merge==2

drop _merge
merge 1:1 Prov YM using MonthlyCovidCasesCanada.dta 
assert _merge==1 if Territories==1 & YM<tm(2020Feb)
assert _merge==3 if Territories==0 & YM>=tm(2020Feb)
assert TotDeathsThisMonth==0 if YM==tm(2020Feb) & TotDeathsThisMonth!=.
replace TotDeathsPriorMonth=0 if YM<tm(2020Feb) & Territories==0
replace TotDeathsThisMonth=0 if YM<tm(2020Feb) & Territories==0
replace TotDeathsNextMonth=0 if YM<tm(2020Feb) & Territories==0
drop if Prov == "Tot" | Prov == ""

save CanadaCigSales_011923.dta, replace


/*Province	Date in Effect	Target Age, y
Nova Scotia	May 31, 2015	19
New Brunswick	July 1, 2015	19
Prince Edward Island	October 1, 2015	19
Quebec	November 26, 2015	18
Ontario	January 1, 2016	19
Newfoundland and Labrador	June 7, 2016	19
British Columbia	September 1, 2016	19
Manitoba	October 1, 2017	18
Alberta	No ban	NA
Saskatchewan	No ban	NA
Canada-wide	May 23, 2018	18
*/
use CanadaCigSales_011923.dta, replace
gen AnalyticSamp=(Territories==0 & Prov!="PE" & (Year>2013 | (Year==2013 & M>=7)))

gen AtlBubblePanel=0
	replace AtlBubblePanel=1 if (Prov=="NB" | Prov=="PE" | Prov=="NS" | Prov=="NF") & YM>=tm(2020m7) & YM<tm(2020m12)
estimates clear	

gen EvFlvPolENDS=(Prov=="NS" | Prov=="PE" | Prov=="NB" | Prov=="NT" |  Prov=="NU" | Prov=="BC" | Prov=="ON" | Prov=="SK" )

gen LnCigsPC=ln(CigsPC)
gen CvdDeathsPC=TotDeathsThisMonth/Pop2022
gen Last12M=(YM>=tm(2022m7) & YM<=tm(2023m6) & AnalyticSamp==1 & Prov!="PE")
gen First12M=(YM>=tm(2018m7) & YM<=tm(2019m6) & AnalyticSamp==1 & Prov!="PE")

xtset newid YM  
gen NicCap20mgmL=(Prov=="NS" & YM>=tm(2020m9))  
	replace NicCap20mgmL=1 if (Prov=="BC" & YM>=tm(2020m9))
	replace NicCap20mgmL=1 if (Prov=="ON" & YM>=tm(2020m7))  
	replace NicCap20mgmL=1 if (YM>tm(2021m7))


gen YM_Pol=YM if ENDSFlvPol==1
by newid, sort: egen EventDate=min(YM_Pol)
gen EvEvent=(EventDate!=.)
format EventDate %tm
gen timeToTreat = YM - EventDate

xtset newid YM

//Policy starts September 15
replace ENDSFlvPol = 0.5333 if Prov == "BC" & Year == 2020 & Month == 9
replace NicCap20mgmL = 0.5333 if Prov == "BC" & Year == 2020 & Month == 9

save analytic_cig.dta,replace 

********Stacked Event Study***************
use analytic_cig.dta, replace 
keep if AnalyticSamp == 1
local kappa_pre = 21
local kappa_post= 21

replace GVAR = . if GVAR == 0 
gen first_time_treated = GVAR
gen time_id = YM
gen panel_id = newid
levelsof first_time_treated, local(alist)
di "`alist'"


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

bysort event_time sub_exp treat: egen sub_exp_stack_weight = sum(stack_weight)
bysort event_time sub_exp treat: egen exp_arm_pop = sum(Pop2022)
gen pop_stack_weight = sub_exp_stack_weight * Pop2022/exp_arm_pop

reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe LnCigsPC NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)
matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post


matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")] ,reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] , [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]
//matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")]

*name the columns so they look correct on the x-axis
mat colnames A ="-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

***********Figure 1a*************
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel( 2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'*(`se2')", pos(6) size(12pt))
graph export "Output\Stacked_Log_Cigarettes.pdf", as(pdf) name("Graph") replace


***********Figure 4a************
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") ylabel(-0.3(0.1)0.5)  graphregion(color(white)) xlabel( 2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'**(`se2')", pos(6) size(12pt))
graph export "Output\Stacked_Log_Cigarettes2.pdf", as(pdf) name("Graph") replace


**********Figure 4d**************
sum CigsPC [aw = stack_weight] if timeToTreat<0 & timeToTreat>-13

reghdfe CigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

local att1 = e(b)[1,1]
local att2 : display %5.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %5.3f `se1'

reghdfe CigsPC NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.treat##i._I* [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)
matrix reg1=r(table)

*create a matrix of the coefficients to be used in the event study plot. Note ,  [0\0]
*that this is set for the 5 pre/post period setup. It must be altered if you change 
*kappa_pre or kappa_post


matrix A = reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_1")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_2")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_3")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_4")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_5")], reg1[1..2 ,colnumb(reg1,"1.treat#1._Ievent_tim_6")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_7")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_8")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_9")] ,reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_10")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_11")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_12")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_13")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_14")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_15")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_16")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_17")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_18")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_19")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_20")] , [0\0],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_22")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_23")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_24")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_25")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_26")], reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_27")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_28")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_29")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_30")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_31")] ,  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_32")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_33")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_34")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_35")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_36")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_37")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_38")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_39")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_40")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_41")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_42")],  reg1[1..2 , colnumb(reg1,"1.treat#1._Ievent_tim_43")]

*name the columns so they look correct on the x-axis
mat colnames A ="-21""-20""-19""-18""-17""-16""-15""-14""-13""-12""-11""-10""-9""-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"
*generate and save the event study
coefplot matrix(A), se(A[2]) vertical yline(0) xline(21.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient")  graphregion(color(white)) xlabel( 2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta}(SE) = `att2'**(`se2')", pos(6) size(12pt))
graph export "Output\Stacked_Cigarettes.pdf", as(pdf) name("Graph") replace


*********Table 2 & Estimates in Figure 2a************
eststo: reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions CvdDeathsPC UnEmp [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)
est store cig_results1_1

esttab cig_results1_* using "Output\cig_results.html", replace html label brackets cells(b(fmt(3) star) se(fmt(3) par)) stats(N, labels("N") fmt(%9.0fc %4.3f  ))  alignment(center) star(* 0.1 ** 0.05 *** 0.01) keep(ENDSFlvPol)


//Drop early COVID19 Pandemic months
drop if Year == 2020 & M >=3 & M <= 8 
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)


********Figure 2a - All Provinces and Territories***************
use analytic_cig.dta, replace 
local kappa_pre = 21
local kappa_post= 21

replace GVAR = . if GVAR == 0 
gen first_time_treated = GVAR
gen time_id = YM
gen panel_id = newid
levelsof first_time_treated, local(alist)
di "`alist'"


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

reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)





********Figure 3a:One Adopter at a Time**********
use analytic_cig.dta, replace 
keep if AnalyticSamp == 1

local kappa_pre = 21
local kappa_post= 21

replace GVAR = . if GVAR == 0 
gen first_time_treated = GVAR
gen time_id = YM
gen panel_id = newid
levelsof first_time_treated, local(alist)
di "`alist'"


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

// Baseline
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

//BC
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight] if sub_exp == 728, cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

//SK
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight] if sub_exp == 740 & panel_id !=4, cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

//NB
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight] if sub_exp == 740 & panel_id !=12, cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

//NS
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight] if sub_exp == 723, cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

//ON
reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight] if sub_exp == 726, cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)


**********Figure 4b: TWFE*********************
use analytic_cig.dta, replace 
keep if AnalyticSamp == 1
keep if Year >=2018
drop if Year == 2018 & M<7

gen ttt = timeToTreat
gen coef = . 
gen se = . 
gen ci_lower = .
gen ci_upper = .

xtset newid YM
tab timeToTreat

reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML UnEmp CvdDeathsPC AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions if AnalyticSamp == 1, absorb(YM newid) vce(cluster newid)
local att1 = e(b)[1,1]
local att2 : display %4.3f `att1'
local se1 = sqrt(e(V)[1,1]) 
local se2 : display %4.3f `se1'

sum timeToTreat
replace timeToTreat = timeToTreat + 38
replace timeToTreat = 37 if timeToTreat == . 

reghdfe LnCigsPC ib37.timeToTreat NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML UnEmp CvdDeathsPC AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions if AnalyticSamp == 1, absorb(YM newid) vce(cluster newid)

forvalues i = 0/80{
 display `i'
replace coef     = r(table)[1, `i'] if ttt ==(`i'-39)
replace  se      = r(table)[2, `i'] if ttt ==(`i'-39)
replace ci_lower = r(table)[5, `i'] if ttt ==(`i'-39)
replace ci_upper = r(table)[6, `i'] if ttt ==(`i'-39)
}


duplicates drop  ttt,force

sort ttt

drop if ttt>21
drop if ttt<-21
twoway (scatter coef ttt, msize(small)) (rcap ci_upper ci_lower ttt, color(stc1)),yline(0) xline(-0.5) xlabel(-20(5)20,nogrid) ylabel(-0.3(0.1)0.5) graphregion(color(white)) xtitle(Months to Flavor Restriction) ytitle("Estimated Coefficient") note("ATT: {&beta}(SE) = `att2'**(`se2')", pos(6) size(12pt)) legend(off) scale(1.2)
graph export "Output\Log_Cig_Event_Study.pdf", as(pdf) name("Graph") replace


*********Figure 4c: SDID Event Study************
use analytic_cig.dta, replace 
keep if AnalyticSamp == 1
keep if Year >=2018
drop if Year == 2018 & M<7
replace ENDSFlvPol = 1 if ENDSFlvPol >0

gen ttt = timeToTreat
gen coef = . 
gen ci_lower = .
gen ci_upper = .


sdid_event LnCigsPC newid YM ENDSFlvPol, placebo(all) covariates(NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions CvdDeathsPC UnEmp) vce(bootstrap) brep(1000)

local att1 = e(H)[1,1]
local att2 : display %4.3f `att1'
local se1 = e(H)[1,2]
local se2 : display %4.3f `se1'

forvalues i = 2/40{
	replace coef = e(H)[`i', 1]      if ttt == (`i'-2)
	replace ci_lower = e(H)[`i', 3]  if ttt == (`i'-2)
	replace ci_upper = e(H)[`i', 4]  if ttt == (`i'-2)
}


forvalues i = 41/80 {
    local ttt = `i' - 39
    replace coef     = e(H)[`i', 1] if ttt == -`ttt'
    replace ci_lower = e(H)[`i', 3] if ttt == -`ttt'
    replace ci_upper = e(H)[`i', 4] if ttt == -`ttt'
}

replace coef = 0 if ttt == -1

drop if ttt>21
drop if ttt<-21

duplicates drop ttt, force

twoway (scatter coef ttt, msize(small)) (rcap ci_upper ci_lower ttt, color(stc1)),yline(0) xline(-0.5) xlabel(-20(5)20,nogrid) ylabel(-0.3(0.1)0.5) graphregion(color(white)) xtitle(Months to Flavor Restriction) ytitle("Estimated Coefficient") note("ATT: {&beta}(SE) = `att2'*(`se2')", pos(6) size(12pt)) legend(off) scale(1.2)

graph export "Output\SDID_Log_Cig_Event_Study.pdf", as(pdf) name("Graph") replace


******Table 1: Summary Stats**************
use analytic_cig.dta, replace 
keep if AnalyticSamp == 1
keep if Year >= 2018
drop if Year == 2018 & M<7
drop if Year == 2023 & M>6

sum CigsPC
keep if Year == 2018 | Year == 2019 | Year == 2022 | Year == 2023
drop if Year == 2019 & M>6
drop if Year == 2022 & M<7

sum CigsPC if First12M == 1 & EvFlvPolENDS==0
sum CigsPC if Last12M == 1 & EvFlvPolENDS==0
sum CigsPC if First12M == 1 & EvFlvPolENDS==1
sum CigsPC if Last12M == 1 & EvFlvPolENDS==1

regress CigsPC i.Last12M  i.EvFlvPolENDS i.Last12M#i.EvFlvPolENDS

******Figure A1:Sales Trends**************
use analytic_cig.dta, replace 
keep if AnalyticSamp == 1
drop if Year <2018
drop if Year == 2018 & M<7
drop if Year == 2023 & M>6

gen treated = 0 
replace treated = 1 if timeToTreat != . 

collapse (mean) CigsPC, by(YM treated)

gen time = YM

twoway (line CigsPC YM if treated == 1, color(maroon)) (line CigsPC YM if treated == 0, color(navy) lpattern(longdash)), xtitle("") ytitle("Cigarettes per Capita") xline(722.5 725.5 727.5 739.5) ylabel(0(20)80) xlabel(,nogrid) legend(order(1 "Treatment Provinces" 2 "Control Provinces") pos(6) cols(2)) text(83 722.3  "NS" 83 725.3  "ON" 83 727.4  "BC" 83 739.3  "NB & SK", place(left) color(black) size(small))
graph export "Output\Sales_Trends_Cigarettes.pdf", as(pdf) name("Graph") replace

log close


 