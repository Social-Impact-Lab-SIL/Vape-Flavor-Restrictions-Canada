* Consolidated Canada flavor-restrictions do-file
* Analyses are ordered as Figures 1-5, Tables 1-3, then Appendix A1-A5 and A2.
* July 1, 2022 populations throughout; cigarette and Google Trends share covariates.
* Newfoundland and Labrador is NL in all analytic datasets.
* Run from the original project directory; original Data, temp, and Output paths are unchanged.
capture log close
log using "Flavor_Restriction_Combined2.log", replace text

*===============================================================
* 1. Cigarette data preparation
*===============================================================
clear all

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
	replace Prov="NL" if prname=="Newfoundland and Labrador"
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
	replace TotDeathsPriorMonth=numdeaths if date=="4/1/23" & (prname=="Prince Edward Island" | prname=="Newfoundland and Labrador") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6/7)) if date=="4/1/23" & prname=="New Brunswick" & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(9/7)) if date=="4/1/23" & prname=="Nova Scotia" & TotDeathsPriorMonth==.
	*From 4/29/23 to 5/6/23, ∆numdeaths=0 in PEI & NB; ∆numdeaths=9 in NS; ∆numdeaths=4 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if date=="5/6/23" & (prname=="Prince Edward Island" | prname=="New Brunswick") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6*(4/7))) if date=="5/6/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6*(9/7))) if date=="5/6/23" & prname=="Nova Scotia" & TotDeathsPriorMonth==.
	*From 5/27/23 to 6/3/23, ∆numdeaths=0 in PEI, NB, & NS; ∆numdeaths=3 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if date=="6/3/23" & (prname=="Prince Edward Island" | prname=="New Brunswick" | prname=="Nova Scotia") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(3*(3/7))) if date=="6/3/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	*From 6/24/23 to 7/1/23, ∆numdeaths=0 in PEI, NB, & NS; ∆numdeaths=5 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if date=="7/1/23" & (prname=="Prince Edward Island" | prname=="New Brunswick" | prname=="Nova Scotia") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(5/7)) if date=="7/1/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	*From 2/25/23 to 3/4/23, ∆numdeaths=0 in Newfoundland and Labrador 
	*From 1/28/23 to 2/4/23, ∆numdeaths=0 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if (date=="3/4/23" | date=="2/4/23") & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	
assert TotDeathsPriorMonth!=.
assert TotDeathsPriorMonth==L.TotDeathsEndThisMonth if L.TotDeathsEndThisMonth!=. & TotDeathsPriorMonth!=. & YM!=tm(2020feb)
keep prname TotDeathsPriorMonth YM newid    
gen Prov="BC" if prname=="British Columbia"
	replace Prov="NB" if prname=="New Brunswick"
	replace Prov="MB" if prname=="Manitoba"
	replace Prov="NL" if prname=="Newfoundland and Labrador"
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
	replace Prov="NL" if Province=="NewfoundlandandLabrador"
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
	replace Prov="NL" if Province=="Newfoundland and Labrador"
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
	rename NF NL
	foreach Y in AB BC MB NB NL NS NT NU ON PE QC SK YT Tot {
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
	rename NF NL
	foreach Y in AB BC MB NB NL NS NT NU ON PE QC SK YT Tot {
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
	rename NF NL
	foreach Y in AB BC MB NB NL NS NT NU ON PE QC SK YT Tot {
		rename `Y' CigsSales_`Y'
	}	
	reshape long CigsSales_, i(Months) j(Prov) string
	rename CigsSales_ CigsSales
	keep if Months!=""
	gen Year=`x'
	save "temp\CigsSales`x'.dta", replace
	clear
}

use "temp\CigsSales2022.dta", clear
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
gen Pop2022=525972 if Prov=="NL"
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

gen YM=ym(Year,M)
gen CigTax=20 if Prov=="AB" & date>=td(8April2009) & date<td(27March2015)
	replace CigTax=22.5 if Prov=="AB" & date>=td(27March2015) & date<td(28Oct2015)
	replace CigTax=25 if Prov=="AB" & date>=td(28Oct2015) & date<td(25Oct2019)
	replace CigTax = (24/31)*25 + (7/31)*27.5 if Prov=="AB" & YM==tm(2019m10)
	replace CigTax=27.5 if Prov=="AB" & date>=td(25Oct2019)	 	
	replace CigTax=21.3 if Prov=="BC" & date>=td(1Apr2013) & date<td(13Oct2013)
	replace CigTax=22.3 if Prov=="BC" & date>=td(13Oct2013) & date<td(01April2014)
	replace CigTax=23.9 if Prov=="BC" & date>=td(01April2014) & date<td(01Oct2017)
	replace CigTax=24.7 if Prov=="BC" & date>=td(01Oct2017) & date<td(01April2018)
	replace CigTax=27.5 if Prov=="BC" & date>=td(01April2018) & date<td(01Jan2020)
	replace CigTax=29.5 if Prov=="BC" & date>=td(01Jan2020) & date<td(01July2021)
	replace CigTax=32.5 if Prov=="BC" & date>=td(01July2021)	 	
	replace CigTax=29 if Prov=="MB" & date>=td(16April2013) & date<td(30April2015)
	replace CigTax=29.5 if Prov=="MB" & date>=td(30April2015) & date<td(30June2019)
	replace CigTax=30 if Prov=="MB" & date>=td(30June2019)	 	
	replace CigTax=19 if Prov=="NB" & date>=td(01July2013) & date<td(03Feb2016)
	replace CigTax=22.26 if Prov=="NB" & date>=td(03Feb2016) & date<td(01Feb2017)
	replace CigTax=25.52 if Prov=="NB" & date>=td(01Feb2017)	 	
	replace CigTax=20.5 if Prov=="NL" & date>=td(27March2013) & date<td(28March2014)
	replace CigTax=23.5 if Prov=="NL" & date>=td(28March2014) & date<td(15April2016)
	replace CigTax=24.5 if Prov=="NL" & date>=td(15April2016) & date<td(01Oct2020)
	replace CigTax=29.5 if Prov=="NL" & date>=td(01Oct2020) & date<td(01jun2021)
	replace CigTax=32.5 if Prov=="NL" & date>=td(01jun2021)	 	
	replace CigTax=23.52 if Prov=="NS" & date>=td(5April2013) & date<td(10April2015)
	replace CigTax=25.52 if Prov=="NS" & date>=td(10April2015) & date<td(20April2016)
	replace CigTax=27.52 if Prov=="NS" & date>=td(20April2016) & date<td(26-Feb2020)
	replace CigTax = (25/29)*27.52 + (4/29)*29.52 if Prov=="NS" & YM==tm(2020m2)
	replace CigTax=29.52 if Prov=="NS" & date>=td(26Feb2020)	
	replace CigTax=12.35 if Prov=="ON" & date>=td(27March2013) & date<td(02May2014)
	replace CigTax=13.975 if Prov=="ON" & date>=td(02May2014) & date<td(26Feb2016)
	replace CigTax=15.475 if Prov=="ON" & date>=td(26Feb2016) & date<td(28April2017)
	replace CigTax=16.475 if Prov=="ON" & date>=td(28April2017) & date<td(29March2018)
	replace CigTax=18.475 if Prov=="ON" & date>=td(29March2018)	 	 
	replace CigTax=14.7 if Prov=="QC" & date>=td(21Nov2012) & date<td(04May2014) //HealthCanada says 5/4/14. Review doc says 6/5/14.
	replace CigTax=14.9 if Prov=="QC" & date>=td(04May2014) & date<td(09Feb2023)
	replace CigTax = (8/28)*14.9 + (20/28)*18.9 if Prov=="QC" & YM==tm(2023m2)
	replace CigTax=18.9 if Prov=="QC" & date>=td(09Feb2023)	 	
	replace CigTax=25 if Prov=="SK" & date>=td(21March2013) & date<td(27March2017)
	replace CigTax=27 if Prov=="SK" & date>=td(27March2017) & date<td(24March2022)
	replace CigTax = (23/31)*27 + (8/31)*29 if Prov=="SK" & YM==tm(2022m3)
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
	replace CigTax = (14/31)*25 + (17/31)*27.52 if Prov=="PE" & YM==tm(2020m7)
	replace CigTax = (6/31)*27.52 + (25/31)*29.52 if Prov=="PE" & YM==tm(2022m5)
	replace CigTax=21 if Prov=="YT" & date>=td(01July2008) & date<td(01July2017)
	replace CigTax=25 if Prov=="YT" & date>=td(01July2017) & date<td(01April2018)
	replace CigTax=30 if Prov=="YT" & date>=td(01April2018) & date<td(01jan2021)
	replace CigTax=31 if Prov=="YT" & date>=td(01jan2021) & date<td(01jan2023)
	replace CigTax=32 if Prov=="YT" & date>=td(01jan2023)			
	label var CigTax "Cigarette Tax in cents/stick"
	drop if Months=="Total" | Prov=="Tot"
	
gen EvFlvBanENDS=(Prov=="NS" | Prov=="PE" | Prov=="NB" | Prov=="NT" |  Prov=="NU")
gen EvFlvRestENDS=(Prov=="BC" | Prov=="ON" | Prov=="SK" )
	 
*https://globalnews.ca/news/10078342/vaping-taxes-canada/	 
gen ENDSTax_Perc=0
	replace ENDSTax_Perc=20-7 if Prov=="BC" & date>=td(01jan2020)  
	replace ENDSTax_Perc=20 if Prov=="NL" & date>=td(01jan2021)  
	*replace ENDSTax_Perc=7 if Prov=="BC" & date<td(01jan2021) <--suspect this is the provincial tax rate 
	replace ENDSTax_Perc=(16/30)*20 if Prov=="NS" & YM==tm(2020m9)
	replace ENDSTax_Perc=20 if Prov=="NS" & date>=td(15sept2020)   
	replace ENDSTax_Perc=14 if Prov=="SK" & date>=td(01sept2021)
gen ENDSTax_PerML=0
	replace ENDSTax_PerML=(16/30)*50 if Prov=="NS" & YM==tm(2020m9)
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
	replace ProvMentholCigBanDate=td(1July2017) if Prov=="NL"  
	replace ProvMentholCigBanDate=td(2Oct2017) if ProvMentholCigBanDate==. 
	format ProvMentholCigBanDate %td
gen FirstOfMonth=mdy(M,1,Year)
	gen MentholCigBan=(YM>tm(2017Oct))
	replace MentholCigBan=1 if YM>tm(2017July) & Prov=="NL"  
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
	replace BanVapingSalesToMinors=1 if YM>tm(2016June) & Prov=="NL"
	replace BanVapingSalesToMinors=1 if YM>=tm(2016Sept) & Prov=="BC"
	replace BanVapingSalesToMinors=1 if YM>=tm(2017Oct) & Prov=="MB"
	
gen AtlBubble=(Prov=="NB" | Prov=="PE" | Prov=="NS" | Prov=="NL" )
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
drop if inlist(Prov, "YT", "NT", "NU")
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
use CanadaCigSales_011923.dta, clear
gen AnalyticSamp=(Territories==0 & Prov!="PE" & (Year>2013 | (Year==2013 & M>=7)))

gen AtlBubblePanel=0
	replace AtlBubblePanel=1 if (Prov=="NB" | Prov=="PE" | Prov=="NS" | Prov=="NL") & YM>=tm(2020m7) & YM<tm(2020m12)
estimates clear	

gen EvFlvPolENDS=(Prov=="NS" | Prov=="PE" | Prov=="NB" | Prov=="NT" |  Prov=="NU" | Prov=="BC" | Prov=="ON" | Prov=="SK" )

gen LnCigsPC=ln(CigsPC)
gen CvdDeathsPC=TotDeathsThisMonth/Pop2022
gen Last12M=(YM>=tm(2022m7) & YM<=tm(2023m6) & AnalyticSamp==1 & Prov!="PE")
gen First12M=(YM>=tm(2018m7) & YM<=tm(2019m6) & AnalyticSamp==1 & Prov!="PE")

xtset newid YM  
* Nova Scotia 20 mg/mL limit: September 1, 2020 (full month)
gen NicCap20mgmL=(Prov=="NS" & YM>=tm(2020m9))  
	replace NicCap20mgmL=1 if (Prov=="BC" & YM>=tm(2020m9))
	replace NicCap20mgmL=1 if (Prov=="ON" & YM>=tm(2020m7))  
	replace NicCap20mgmL=9/31 if YM==tm(2021m7) & NicCap20mgmL==0
	replace NicCap20mgmL=1 if (YM>=tm(2021m8))


gen YM_Pol=YM if ENDSFlvPol==1
by newid, sort: egen EventDate=min(YM_Pol)
gen EvEvent=(EventDate!=.)
format EventDate %tm
gen timeToTreat = YM - EventDate

xtset newid YM

//Policy starts September 15
replace ENDSFlvPol = 16/30 if Prov=="BC" & YM==tm(2020m9)
replace NicCap20mgmL = 16/30 if Prov=="BC" & YM==tm(2020m9)

gen CvdDeathsPC_prev3 = 0
xtset newid YM

forvalues l = 1/3 {
    replace CvdDeathsPC_prev3 = CvdDeathsPC_prev3 + L`l'.CvdDeathsPC
}

sort newid YM
by newid: gen CvdDeathsPC_cum = sum(CvdDeathsPC)
gen CvdDeathsPC_cum_lag = L.CvdDeathsPC_cum

save analytic_cig.dta,replace

*===============================================================
* 2. NVP data preparation
*===============================================================
*Unemployment Rate - https://www.stats.gov.nl.ca/Statistics/Topics/labour/PDF/UnempRate_Monthly.pdf (webarchive)
import excel "Data\UnempRate_Monthly.xlsx", sheet("Stata") firstrow clear
foreach P in Alberta BritishColumbia Canada  NewBrunswick Manitoba NewfoundlandandLabrador NovaScotia Ontario PrinceEdwardIsland Quebec Saskatchewan {
	rename `P' UnEmp`P'
}

local nb_share = 812061 / (1019725 + 170688 + 812061)
local pei_share = 170688 / (1019725 + 170688 + 812061)
local ns_share = 1019725 / (1019725 + 170688 + 812061)
local sk_share = 1194803 / (1194803 + 1409223)
local mb_share = 1409223 / (1194803 + 1409223)

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
	replace Prov="NL" if prname=="Newfoundland and Labrador"
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
	replace TotDeathsPriorMonth=numdeaths if date=="4/1/23" & (prname=="Prince Edward Island" | prname=="Newfoundland and Labrador") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6/7)) if date=="4/1/23" & prname=="New Brunswick" & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(9/7)) if date=="4/1/23" & prname=="Nova Scotia" & TotDeathsPriorMonth==.
	*From 4/29/23 to 5/6/23, ∆numdeaths=0 in PEI & NB; ∆numdeaths=9 in NS; ∆numdeaths=4 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if date=="5/6/23" & (prname=="Prince Edward Island" | prname=="New Brunswick") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6*(4/7))) if date=="5/6/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(6*(9/7))) if date=="5/6/23" & prname=="Nova Scotia" & TotDeathsPriorMonth==.
	*From 5/27/23 to 6/3/23, ∆numdeaths=0 in PEI, NB, & NS; ∆numdeaths=3 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if date=="6/3/23" & (prname=="Prince Edward Island" | prname=="New Brunswick" | prname=="Nova Scotia") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(3*(3/7))) if date=="6/3/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	*From 6/24/23 to 7/1/23, ∆numdeaths=0 in PEI, NB, & NS; ∆numdeaths=5 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if date=="7/1/23" & (prname=="Prince Edward Island" | prname=="New Brunswick" | prname=="Nova Scotia") & TotDeathsPriorMonth==.
	replace TotDeathsPriorMonth=(numdeaths-(5/7)) if date=="7/1/23" & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	*From 2/25/23 to 3/4/23, ∆numdeaths=0 in Newfoundland and Labrador 
	*From 1/28/23 to 2/4/23, ∆numdeaths=0 in Newfoundland and Labrador 
	replace TotDeathsPriorMonth=numdeaths if (date=="3/4/23" | date=="2/4/23") & prname=="Newfoundland and Labrador" & TotDeathsPriorMonth==.
	
assert TotDeathsPriorMonth!=.
assert TotDeathsPriorMonth==L.TotDeathsEndThisMonth if L.TotDeathsEndThisMonth!=. & TotDeathsPriorMonth!=. & YM!=tm(2020feb)
keep prname TotDeathsPriorMonth YM newid Month Year  
gen Prov="BC" if prname=="British Columbia"
	replace Prov="NB" if prname=="New Brunswick"
	replace Prov="MB" if prname=="Manitoba"
	replace Prov="NL" if prname=="Newfoundland and Labrador"
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

save "temp\covid_temp.dta",replace
drop if prname == "Prince Edward Island"

collapse (sum) TotDeathsThisMonth, by(Month Year newid)
gen province = "AB" if newid == 1
replace province = "BC" if newid == 2
replace province = "MB" if newid == 4
replace province = "NB" if newid == 5
replace province = "NL" if newid == 6
replace province = "NS" if newid == 8
replace province = "ON" if newid == 10
replace province = "QC" if newid == 12
replace province = "SK" if newid == 14

save "temp\covid_temp2.dta",replace

use "temp\covid_temp.dta",clear
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
	replace Prov="NL" if Province=="Newfoundland and Labrador"
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

* July 1, 2022 populations for province-group-weighted COVID restrictions
gen pop=1019725 if Prov=="NS"
replace pop=170688 if Prov=="PE"
replace pop=812061 if Prov=="NB"
replace pop=1194803 if Prov=="SK"
replace pop=1409223 if Prov=="MB"
replace pop=4543111 if Prov=="AB"
replace pop=5319324 if Prov=="BC"
replace pop=15109416 if Prov=="ON"
replace pop=8695659 if Prov=="QC"

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
*Appears 949 duplicate rows for 2022
duplicates drop


/*
July 1, 2022 populations (Statistics Canada, Table 17-10-0009-01).
SK 1,194,803; MB 1,409,223; NS 1,019,725; PEI 170,688; NB 812,061.
Population shares below are used for both aggregated NielsenIQ province groups.
*/

local nb_share = 812061 / (1019725 + 170688 + 812061)
local pei_share = 170688 / (1019725 + 170688 + 812061)
local ns_share = 1019725 / (1019725 + 170688 + 812061)
local sk_share = 1194803 / (1194803 + 1409223)
local mb_share = 1409223 / (1194803 + 1409223)

rename Column1 price_per_unit
//destring Nicotineconetentmgml, replace

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

*Check that no duplicates
duplicates drop province startyear startmonth startday UPC channel, force

egen province_dum = group(province)
egen time = group(startyear startmonth startday)

gen product_volume = .
gen desc = strtrim(upper(Description))

* JUUL
replace product_volume = 2.4 if Brand=="JUUL" & strpos(desc,"JUUL 2 POD") & regexm(desc,"(^|[^0-9])2S([^A-Z0-9]|$)")
replace product_volume = 2.4 if Brand=="JUUL" & strpos(desc,"JUUL POD 2 ") & regexm(desc,"(^|[^A-Z0-9])2S([^A-Z0-9]|$)")
replace product_volume = 2.8 if Brand=="JUUL" & strpos(desc,"2.8ML")
replace product_volume = 2.8 if Brand=="JUUL" & regexm(desc,"(^|[^0-9])4S([^A-Z0-9]|$)") & product_volume==.
replace product_volume = 1.4 if Brand=="JUUL" & regexm(desc,"(^|[^0-9])2S([^A-Z0-9]|$)") & product_volume==.
replace product_volume = 0.7 if Brand=="JUUL" & regexm(desc,"(^|[^0-9])1S([^A-Z0-9]|$)") & product_volume==.

* VUSE/VYPE
gen vuse_count = .
replace vuse_count = real(regexs(1))*real(regexs(2)) if inlist(Brand,"VUSE","VYPE") & regexm(desc,"([0-9]+)[ ]*X[ ]*([0-9]+)S([^A-Z0-9]|$)")
replace vuse_count = real(regexs(2)) if inlist(Brand,"VUSE","VYPE") & vuse_count==. & regexm(desc,"(^|[^0-9])([0-9]+)S([^A-Z0-9]|$)")

replace product_volume = 10*vuse_count if inlist(Brand,"VUSE","VYPE") & strpos(desc,"GO 5000")
replace product_volume = 4.8*vuse_count if inlist(Brand,"VUSE","VYPE") & strpos(desc,"GO XL")
replace product_volume = 2*vuse_count if inlist(Brand,"VUSE","VYPE") & strpos(desc," GO ") & product_volume==.
replace product_volume = 1.9*vuse_count if inlist(Brand,"VUSE","VYPE") & (strpos(desc,"EPOD") | strpos(desc,"EPD")) & producttype=="cartridge" & !strpos(desc,"KIT") & !strpos(desc,"COMBO") & product_volume==.
replace product_volume = 2*vuse_count if inlist(Brand,"VUSE","VYPE") & (regexm(desc,"E[ ]*PEN[ ]*3([^0-9]|$)") | strpos(desc,"VUSE EPEN")) & producttype=="cartridge" & product_volume==.
replace product_volume = 1.5*vuse_count if Brand=="VYPE" & strpos(desc,"E PEN") & !regexm(desc,"E[ ]*PEN[ ]*3([^0-9]|$)") & producttype=="cartridge" & product_volume==.
replace product_volume = 10*vuse_count if Brand=="VYPE" & strpos(desc,"ELIQUID") & product_volume==.
replace product_volume = 3.8 if Brand=="VYPE" & producttype=="cartridge" & strpos(desc,"POLAR MINT 12MG 2S") & product_volume==.
replace product_volume = .9*vuse_count if Brand=="VYPE" & strpos(desc,"E STICK") & producttype=="cartridge" & product_volume==.

* Extract stated mL
gen double desc_ml = .
replace desc_ml = real(regexs(2)) if regexm(desc,"(^|[^0-9.])([0-9]+([.][0-9]+)?)[ ]*ML")
replace product_volume = desc_ml if inlist(Brand,"ALLO","PUFF","POP","GHOST","GCORE") & desc_ml!=.

* ALLO
replace product_volume = 2 if Brand=="ALLO" & regexm(desc,"ULTRA 500([^0-9]|$)") & product_volume==.
replace product_volume = 3.8 if Brand=="ALLO" & regexm(desc,"ULTRA 800([^0-9]|$)") & product_volume==.
replace product_volume = 6.8 if Brand=="ALLO" & regexm(desc,"ULTRA 1600([^0-9]|$)") & product_volume==.
replace product_volume = 10 if Brand=="ALLO" & regexm(desc,"ULTRA 2500([^0-9]|$)") & product_volume==.

* PUFF
replace product_volume = 1.3 if Brand=="PUFF" & strpos(desc,"PUFF BAR") & product_volume==.

* STIG
replace product_volume = 3.6 if Brand=="STIG" & regexm(desc,"(^|[^0-9])3S([^A-Z0-9]|$)") & (desc_ml==. | inlist(desc_ml,1.2,3.6)) & product_volume==.
replace product_volume = 1.2 if Brand=="STIG" & regexm(desc,"(^|[^0-9])1S([^A-Z0-9]|$)") & (desc_ml==. | desc_ml==1.2) & product_volume==.

* POP
replace product_volume = 4 if Brand=="POP" & strpos(desc,"EXTRA") & product_volume==.
replace product_volume = 1.2 if Brand=="POP" & !strpos(desc,"EXTRA") & !strpos(desc,"HYBRID") & product_volume==.

* GHOST
replace product_volume = 8 if Brand=="GHOST" & strpos(desc,"BOX") & product_volume==.
replace product_volume = 9 if Brand=="GHOST" & strpos(desc,"MEGA") & product_volume==.
replace product_volume = 6 if Brand=="GHOST" & strpos(desc,"MAX") & product_volume==.
replace product_volume = 3.2 if Brand=="GHOST" & strpos(desc,"XL") & product_volume==.

* GCORE
replace product_volume = 17 if Brand=="GCORE" & regexm(desc,"(^|[^0-9])7500([^0-9]|$)") & product_volume==.
replace product_volume = 15 if Brand=="GCORE" & regexm(desc,"(^|[^0-9])7000([^0-9]|$)") & product_volume==.
replace product_volume = 10 if Brand=="GCORE" & regexm(desc,"(^|[^0-9])3500([^0-9]|$)") & product_volume==.
replace product_volume = 9 if Brand=="GCORE" & regexm(desc,"(^|[^0-9])3000([^0-9]|$)") & product_volume==.
replace product_volume = 9 if Brand=="GCORE" & strpos(desc,"HIT") & product_volume==.
replace product_volume = 6.2 if Brand=="GCORE" & regexm(desc,"(^|[^0-9])1800([^0-9]|$)") & product_volume==.
replace product_volume = 2 if Brand=="GCORE" & regexm(desc,"(^|[^0-9])1000([^0-9]|$)") & product_volume==.

* VEEV ONE
replace product_volume = 4 if Brand=="VEEV" & producttype=="cartridge" & strpos(desc,"VEEV ONE") & regexm(desc,"(^|[^A-Z0-9])2S([^A-Z0-9]|$)")

* Other cartridge brands
replace product_volume = 1.5*2 if Brand=="VEEV" & producttype=="cartridge" & !regexm(desc,"^VEEV (POD |VAPE )?ONE([^A-Z0-9]|$)") & product_volume==.
replace product_volume = 1.6*2 if Brand=="LOGIC" & producttype=="cartridge" & product_volume==.
replace product_volume = 2*3 if Brand=="ALLO" & producttype=="cartridge" & product_volume==.
replace product_volume = 1.5*2 if Brand=="MYBLU" & producttype=="cartridge" & product_volume==.
replace product_volume = 2*3 if Brand=="Z PODS" & producttype=="cartridge" & product_volume==.
replace product_volume = .9*4 if Brand=="MYLE" & producttype=="cartridge" & product_volume==.
replace product_volume = 1.9*2 if Brand=="RELX" & producttype=="cartridge" & product_volume==.
replace product_volume = 2*3 if Brand=="STLTH" & producttype=="cartridge" & !strpos(desc,"SNAP") & product_volume==.
replace product_volume = 2*3 if Brand=="ZIIPLAB" & producttype=="cartridge" & product_volume==.

* BOOSTED
replace product_volume = 6 if Brand=="BOOSTED" & producttype=="cartridge" & desc_ml==2 & regexm(desc,"(^|[^A-Z0-9])3S([^A-Z0-9]|$)")

* VEEBA / VEEV NOW
replace product_volume = 5 if Brand=="VEEV" & producttype=="disposable" & strpos(desc,"VEEV NOW") & desc_ml==5 & regexm(desc,"(^|[^A-Z0-9])1S([^A-Z0-9]|$)")
replace product_volume = 2 if Brand=="VEEBA" & producttype=="disposable" & product_volume==.
replace product_volume = 2 if Brand=="VEEV" & strpos(desc,"VEEV NOW") & producttype=="disposable" & product_volume==.

* STLTH disposables
replace product_volume = 2 if Brand=="STLTH" & producttype=="disposable" & regexm(desc,"(^|[^0-9])1000([^0-9]|$)") & product_volume==.
replace product_volume = 6 if Brand=="STLTH" & producttype=="disposable" & regexm(desc,"(^|[^0-9])3000([^0-9]|$)") & product_volume==.
replace product_volume = 10 if Brand=="STLTH" & producttype=="disposable" & regexm(desc,"(^|[^0-9])5000([^0-9]|$)") & product_volume==.
replace product_volume = 14 if Brand=="STLTH" & producttype=="disposable" & regexm(desc,"(^|[^0-9])8000([^0-9]|$)") & product_volume==.

* FLAVOUR BEAST
replace product_volume = 16 if Brand=="FLAVOUR BEAST" & regexm(desc,"(^|[^0-9])8000([^0-9]|$)") & product_volume==.
replace product_volume = 8 if Brand=="FLAVOUR BEAST" & regexm(desc,"(^|[^0-9])3000([^0-9]|$)") & product_volume==.
replace product_volume = 10 if Brand=="FLAVOUR BEAST" & (strpos(desc,"FLOW") | regexm(desc,"(^|[^0-9])4000([^0-9]|$)")) & product_volume==.

* Other disposables
replace product_volume = 10 if strpos(desc,"DRIP N 5000") & producttype=="disposable" & product_volume==.
replace product_volume = 6.5 if Brand=="VICE" & producttype=="disposable" & regexm(desc,"(^|[^0-9])2500([^0-9]|$)") & product_volume==.
replace product_volume = 10 if Brand=="VICE" & producttype=="disposable" & regexm(desc,"(^|[^0-9])5500([^0-9]|$)") & product_volume==.
replace product_volume = 13 if Brand=="VICE" & producttype=="disposable" & (regexm(desc,"(^|[^0-9])6000([^0-9]|$)") | strpos(desc,"VICE BOX")) & product_volume==.
replace product_volume = 6 if strpos(desc,"ENVI APEX") & producttype=="disposable" & product_volume==.
replace product_volume = 15 if strpos(desc,"MR FOG SWITCH 5500") & producttype=="disposable" & product_volume==.
replace product_volume = 10 if strpos(desc,"RUFPUF") & regexm(desc,"(^|[^0-9])4500([^0-9]|$)") & producttype=="disposable" & product_volume==.
replace product_volume = 10 if strpos(desc,"ELF BAR BC 5000") & producttype=="disposable" & product_volume==.
replace product_volume = 1.2 if Brand=="DOSE" & producttype=="disposable" & product_volume==.
replace product_volume = 5 if strpos(desc,"ENVI BOOST") & producttype=="disposable" & product_volume==.
replace product_volume = 2 if strpos(desc,"ENVI NANO") & producttype=="disposable" & product_volume==.
replace product_volume = 17 if strpos(desc,"RUFPUF") & regexm(desc,"(^|[^0-9])7500([^0-9]|$)") & producttype=="disposable" & product_volume==.
replace product_volume = 10 if strpos(desc,"RUFPUF") & regexm(desc,"(^|[^0-9])6000([^0-9]|$)") & producttype=="disposable" & product_volume==.
replace product_volume = 6 if strpos(desc,"BREEZE PRO") & producttype=="disposable" & product_volume==.
replace product_volume = 5.5 if strpos(desc,"WAKA SOLO 1800") & producttype=="disposable" & product_volume==.
replace product_volume = 2 if strpos(desc,"WAKA MINI") & producttype=="disposable" & product_volume==.
replace product_volume = 15 if strpos(desc,"MR FOG") & regexm(desc,"(^|[^0-9])5500([^0-9]|$)") & producttype=="disposable" & product_volume==.
replace product_volume = 2 if strpos(desc,"MR FOG") & regexm(desc,"(^|[^0-9])600([^0-9]|$)") & producttype=="disposable" & product_volume==.

* Remaining products with stated volume
replace product_volume = desc_ml if desc_ml!=. & product_volume==. & !inlist(Brand,"VUSE","VYPE","STIG") & producttype!="kit" & !(Brand=="VEEV" & regexm(desc,"^VEEV (POD |VAPE )?ONE([^A-Z0-9]|$)")) & !(Brand=="STLTH" & strpos(desc,"SNAP"))

* Selected VYPE kits
replace product_volume = 1.9 if Brand=="VYPE" & producttype=="kit" & inlist(UPC,"000005930006176","000005930006212","000005930006400") & product_volume==.

* VYPE ePen3 starter kits
replace product_volume = 4 if Brand=="VYPE" & producttype=="kit" & regexm(desc,"E[ ]*PEN[ ]*3([^0-9]|$)") & (strpos(desc,"STARTER KIT") | strpos(desc,"STRTR KIT")) & regexm(desc,"(^|[^0-9])1S([^A-Z0-9]|$)") & product_volume==.

* UPC-specific verified corrections
replace product_volume = 3.8 if Brand=="VUSE" & UPC=="000005930006642"

replace product_volume = 4 if Brand=="VEEV" & producttype=="cartridge" & inlist(UPC,"000006190049952","000006190049961","000006190049962","000006190049963","000006190049964","000061900499523")

* Starter kits with nicotine explicitly listed in description
replace product_volume = 1.9 if Brand=="VYPE" & producttype=="kit" & strpos(desc,"EPOD") & regexm(desc,"([0-9]+(\.[0-9]+)?)[ ]*(MG|%)") & product_volume==.

replace product_volume = 4 if Brand=="VYPE" & producttype=="kit" & regexm(desc,"E[ ]*PEN[ ]*3([^0-9]|$)") & regexm(desc,"([0-9]+(\.[0-9]+)?)[ ]*(MG|%)") & product_volume==.

replace product_volume = 3 if Brand=="VYPE" & producttype=="kit" & strpos(desc,"E PEN") & !regexm(desc,"E[ ]*PEN[ ]*3([^0-9]|$)") & regexm(desc,"([0-9]+(\.[0-9]+)?)[ ]*(MG|%)") & product_volume==.

replace product_volume = 1.6 if Brand=="LOGIC" & producttype=="kit" & strpos(desc,"POD") & regexm(desc,"([0-9]+(\.[0-9]+)?)[ ]*(MG|%)") & product_volume==.

* Average product volume, weighted by unit sales
summarize product_volume [aw=units] if !missing(product_volume)

* Drop helper variables
drop desc desc_ml vuse_count

gen double nicotine_from_desc = .

replace nicotine_from_desc = real(regexs(2)) if regexm(upper(Description), "(^|[^0-9.])([0-9]+(\.[0-9]+)?)[ ]*MG([^A-Z0-9]|$)")

replace Nicotineconetentmgml = nicotine_from_desc if missing(Nicotineconetentmgml) & inrange(nicotine_from_desc, 0, 60)

replace Nicotineconetentmgml = 0 if missing(Nicotineconetentmgml) & regexm(upper(Description), "(^|[^0-9.])0[ ]*%[ ]*NICOTINE([^A-Z0-9]|$)")

drop nicotine_from_desc

bysort UPC (startyear): replace Nicotineconetentmgml = Nicotineconetentmgml[_n-1] if missing(Nicotineconetentmgml)

gsort UPC -startyear
by UPC: replace Nicotineconetentmgml = Nicotineconetentmgml[_n-1] if missing(Nicotineconetentmgml)

sort UPC startyear

gen volume = product_volume*units
gen nicotine = Nicotineconetentmgml*volume

summarize Nicotineconetentmgml [aw=volume]

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

gen nicotine_tob_unflav = nicotine if tob_unflav_flavored == 1
gen nicotine_flav = nicotine if flavored == 1
gen nicotine_mint = nicotine if mint == 1

* Disposable share of NVP unit sales by province over time
preserve

drop if startyear == 2018 & startmonth < 6
drop if startyear == 2023 & startmonth > 6

* Disposable unit sales
gen disposable_units = units*(producttype=="disposable")

* Collapse to province-period level
collapse (sum) units disposable_units, by(province_dum province time startyear startmonth)

* Disposable share of all NVP unit sales
gen disposable_share = 100*disposable_units/units

* Province names for legend
levelsof province if province_dum==1, local(p1) clean
levelsof province if province_dum==2, local(p2) clean
levelsof province if province_dum==3, local(p3) clean
levelsof province if province_dum==4, local(p4) clean
levelsof province if province_dum==5, local(p5) clean
levelsof province if province_dum==6, local(p6) clean

twoway ///
    (line disposable_share time if province_dum==1) ///
    (line disposable_share time if province_dum==2) ///
    (line disposable_share time if province_dum==3) ///
    (line disposable_share time if province_dum==4) ///
    (line disposable_share time if province_dum==5) ///
    (line disposable_share time if province_dum==6), ///
    ytitle("Disposable share of unit sales (%)") ///
    xtitle("") ///
    xlabel(1 "2018" 14 "2019" 28 "2020" 40 "2021" 53 "2022" 67 "2023") ///
    ylabel(, angle(horizontal)) ///
    legend(order(1 "`p1'" 2 "`p2'" 3 "`p3'" 4 "`p4'" 5 "`p5'" 6 "`p6'") ///
        position(6) ring(1) rows(2)) ///
    title("Disposable Share of NVP Unit Sales by Province")

restore





* VUSE GO share of e-cigarette unit sales by province over time
preserve
drop if startyear == 2018 & startmonth<6
drop if startyear == 2023 & startmonth>6
* Identify BAT/Imperial Tobacco's VUSE GO products
gen byte vuse_go = ///
    Brand == "VUSE" & ///
    regexm(upper(Description), "(^|[^A-Z])GO([^A-Z]|$)")

* Check first appearance of VUSE GO by province
bysort province_dum: egen first_go = min(cond(vuse_go == 1, time, .))
egen tag_province = tag(province_dum)

display "========== FIRST VUSE GO OBSERVATION BY PROVINCE =========="
sort province_dum
list province_dum province first_go if tag_province == 1, ///
    noobs clean

drop first_go tag_province

* Calculate VUSE GO unit sales
gen go_units = units*vuse_go

collapse (sum) units go_units, by(province_dum province time)

gen go_share = 100*go_units/units

* Province names for legend
levelsof province if province_dum==1, local(p1) clean
levelsof province if province_dum==2, local(p2) clean
levelsof province if province_dum==3, local(p3) clean
levelsof province if province_dum==4, local(p4) clean
levelsof province if province_dum==5, local(p5) clean
levelsof province if province_dum==6, local(p6) clean

twoway ///
    (line go_share time if province_dum==1) ///
    (line go_share time if province_dum==2) ///
    (line go_share time if province_dum==3) ///
    (line go_share time if province_dum==4) ///
    (line go_share time if province_dum==5) ///
    (line go_share time if province_dum==6), ///
    ytitle("VUSE GO share of unit sales (%)") ///
    xtitle("") ///
    xlabel(1 "2018" 14 "2019" 28 "2020" 40 "2021" 53 "2022" 67 "2023") ///
    ylabel(, angle(horizontal)) ///
    legend(order(1 "`p1'" 2 "`p2'" 3 "`p3'" 4 "`p4'" 5 "`p5'" 6 "`p6'") ///
        position(6) ring(1) rows(2)) ///
    title("VUSE GO Share of E-Cigarette Unit Sales by Province")

restore

* JUUL share of e-cigarette unit sales by province over time
preserve

drop if startyear == 2018 & startmonth<6
drop if startyear == 2023 & startmonth>6

gen juul_units = units*(Brand=="JUUL")

collapse (sum) units juul_units, by(province_dum province time startyear startmonth)

gen juul_share = 100*juul_units/units

* Province names for legend
levelsof province if province_dum==1, local(p1) clean
levelsof province if province_dum==2, local(p2) clean
levelsof province if province_dum==3, local(p3) clean
levelsof province if province_dum==4, local(p4) clean
levelsof province if province_dum==5, local(p5) clean
levelsof province if province_dum==6, local(p6) clean

twoway ///
    (line juul_share time if province_dum==1) ///
    (line juul_share time if province_dum==2) ///
    (line juul_share time if province_dum==3) ///
    (line juul_share time if province_dum==4) ///
    (line juul_share time if province_dum==5) ///
    (line juul_share time if province_dum==6), ///
    ytitle("JUUL share of unit sales (%)") ///
    xtitle("") ///
    xlabel(1 "2018" 14 "2019" 28 "2020" 40 "2021" 53 "2022" 67 "2023") ///
    ylabel(0(10)80, angle(horizontal)) ///
    legend(order(1 "`p1'" 2 "`p2'" 3 "`p3'" 4 "`p4'" 5 "`p5'" 6 "`p6'") position(6) ring(1) rows(2)) ///
    title("JUUL Share of E-Cigarette Unit Sales by Province")

restore

preserve

drop if startyear == 2018 & startmonth<6
drop if startyear == 2023 & startmonth>6

egen total_units = total(units)
egen missing_volume_units = total(units) if missing(product_volume)
egen total_missing_volume_units = max(missing_volume_units)

gen pct_missing_volume = 100*total_missing_volume_units/total_units

display "Percent of unit sales missing volume = " pct_missing_volume[1]

restore

collapse (sum) units volume units_tob_unflav units_flavored units_mint units_stand units_tob_unflav_stand units_flavored_stand units_mint_stand volume_tob_unflav volume_flav volume_mint nicotine nicotine_tob_unflav nicotine_flav nicotine_mint, by(province_dum time province enddate endmonth endday endyear startdate startmonth startday startyear)

gen days_in_period = enddate - startdate 
gen units_per_day = units/days_in_period
gen volume_per_day = volume/days_in_period
gen nicotine_per_day = nicotine/days_in_period
gen nicotine_tob_unflav_per_day = nicotine_tob_unflav/days_in_period
gen nicotine_flav_per_day = nicotine_flav/days_in_period
gen nicotine_mint_per_day = nicotine_mint/days_in_period


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

collapse (sum) units = units_per_day volume = volume_per_day units_tob_unflav = units_tob_unflav_per_day units_flavored = units_flavored_per_day units_mint = units_mint_per_day units_stand = units_stand_per_day units_tob_unflav_stand = units_tob_unflav_stand_per_day units_flavored_stand = units_flavored_stand_per_day units_mint_stand = units_mint_stand_per_day volume_tob_unflav = volume_tob_unflav_per_day volume_flav = volume_flav_per_day volume_mint = volume_mint_per_day nicotine = nicotine_per_day nicotine_tob_unflav = nicotine_tob_unflav_per_day nicotine_flav = nicotine_flav_per_day nicotine_mint = nicotine_mint_per_day, by(province_dum ym province)

gen month = month(dofm(ym))
gen year = year(dofm(ym))

egen time = group(year month)

* July 1, 2022 populations for all NVP per-capita outcomes and weights
gen pop=.
replace pop=1019725 + 170688 + 812061 if province=="Maritimes"
replace pop=1194803 + 1409223 if province=="MB & SK"
replace pop=4543111 if province=="AB"
replace pop=5319324 if province=="BC"
replace pop=15109416 if province=="ON"
replace pop=8695659 if province=="QC"


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

gen volume_per_capita = volume/pop

gen nicotine_per_capita = nicotine/pop
gen nicotine_tob_unflav_per_capita = nicotine_tob_unflav/pop
gen nicotine_flav_per_capita = nicotine_flav/pop
gen nicotine_mint_per_capita = nicotine_mint/pop

gen log_units_per_capita = ln(units_per_capita)
gen log_units_flavored_per_capita = ln(units_flavored_per_capita)
gen log_units_tob_unflav_per_capita = ln(units_tob_unflav_per_capita)
gen log_units_mint_per_capita = ln(units_mint_per_capita)

gen log_volume_per_capita = ln(volume_per_capita)

gen log_nicotine_per_capita = ln(nicotine_per_capita)
gen log_nicotine_flav_per_capita = ln(nicotine_flav_per_capita)
gen log_nicotine_mint_per_capita = ln(nicotine_mint_per_capita)
gen log_nicotine_unflav_per_capita = ln(nicotine_tob_unflav_per_capita)

**********Replace zeros in volume with the average volume of one unit*******

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

gen volume_flav_adj = volume_flav
replace volume_flav_adj = global_average_volume_flav if volume_flav_adj == 0
gen volume_flav_per_capita = volume_flav_adj/pop
gen log_volume_flav_per_capita = ln(volume_flav_per_capita)

gen volume_unflav_adj = volume_tob_unflav
replace volume_unflav_adj = global_average_volume_unflav if volume_unflav_adj == 0
gen volume_unflav_per_capita = volume_unflav_adj/pop
gen log_volume_unflav_per_capita = ln(volume_unflav_per_capita)

gen volume_mint_adj = volume_mint
replace volume_mint_adj = global_average_volume_mint if volume_mint_adj == 0
gen volume_mint_per_capita = volume_mint_adj/pop
gen log_volume_mint_per_capita = ln(volume_mint_per_capita)


gen ENDSTax_Perc = 0
replace ENDSTax_Perc = 13 if province == "BC" & year>= 2020
replace ENDSTax_Perc = (16/30)*20*`ns_share' if province=="Maritimes" & year==2020 & month==9 
replace ENDSTax_Perc = 20 * `ns_share' if province == "Maritimes" & ((year==2020 & month>=10) | year>=2021)
replace ENDSTax_Perc = 14 * `sk_share' if province=="MB & SK" & ((year>=2021 & month>=9) | year>=2022)

gen ENDSTax_PerML = 0 
replace ENDSTax_PerML = (16/30)*50*`ns_share' if province=="Maritimes" & year==2020 & month==9 
replace ENDSTax_PerML = 50 * `ns_share' if province == "Maritimes" & ((year==2020 & month>=10) | year>=2021)

gen cig_tax = .
replace cig_tax = 25 if province=="AB"
replace cig_tax = ((24/31)*25)+((7/31)*27.5) if province=="AB" & month == 10 & year == 2019
replace cig_tax = 27.5 if province=="AB" & ((month>= 11 &year>=2019)| year>=2020)
replace cig_tax = 24.7 if province=="BC"
replace cig_tax = 27.5 if province=="BC" & ((month>=4 & year>=2018) | year>=2019)
replace cig_tax = 29.5 if province=="BC" & ((month>=1 & year>=2020) | year>=2021)
replace cig_tax = 32.5 if province=="BC" & ((month>=7 & year>=2021) | year>=2022)
replace cig_tax = 27 * `sk_share' + 29.5 * `mb_share'  if province=="MB & SK"
replace cig_tax = 27 * `sk_share' + 30 * `mb_share'  if province=="MB & SK" & ((month>= 7 & year >= 2019) | year>=2020)
replace cig_tax = ((23/31)*27 * `sk_share')+((8/31)*29 * `sk_share') + (30 * `mb_share')  if province=="MB & SK" & (month == 3 & year == 2022)
replace cig_tax = 29 * `sk_share' + 30 * `mb_share'  if province=="MB & SK" & ((month>= 4 & year >= 2022) | year>=2023)
replace cig_tax = 25.52 * `nb_share' + 27.52 * `ns_share' + 25 * `pei_share' if province=="Maritimes"
replace cig_tax = 25.52 * `nb_share' + ((25/29)*27.52 * `ns_share') + ((4/29)*29.52 * `ns_share') + 25 * `pei_share' if province=="Maritimes" & (month == 2 & year==2020) 
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + 25 * `pei_share' if province=="Maritimes" & ((month>=3 & year==2020) | year>=2021)
replace cig_tax = 25.52 * `nb_share' + 29.52 * `ns_share' + (14/31*25 * `pei_share')+(17/31*27.52 * `pei_share') if province=="Maritimes" & (month==7 & year==2020)
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
replace ecig_nicotine = ecig_nicotine + ((1-ecig_nicotine)*(9/31)) if month == 7 & year == 2021
replace ecig_nicotine = 1  if ((month>=8 & year==2021) | year>=2022)

gen trade_bubble = 0 
replace trade_bubble = 1 if province == "Maritimes" & year == 2020 & month>=7 & month <=11

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

*===============================================================
* 3. Google Trends outcomes merged into cigarette analytic data
* Both analyses use the SAME province-month covariates and 2022 population.
*===============================================================
import delimited "data\google_trends4.csv", clear
drop date
replace province = "NL" if province == "NF"
keep if inlist(province, "AB", "BC", "MB", "NB") | inlist(province, "NL", "NS", "ON", "QC", "SK")
* Preserve original handling of zero Google Trends scores
replace interest = 7 if interest == 0
replace shopping = 7 if shopping == 0
gen YM = ym(year, month)
format YM %tm
keep if inrange(YM, tm(2018m7), tm(2023m6))
rename province Prov
keep Prov YM shopping interest ecig_search
isid Prov YM
tempfile google_outcomes
save `google_outcomes'

use analytic_cig.dta, clear
isid Prov YM
merge 1:1 Prov YM using `google_outcomes', gen(merge_gt)
assert merge_gt != 2
assert NicCap20mgmL == 1 if Prov == "NS" & YM == tm(2020m9)
save analytic_cig_google.dta, replace

*========================================================================
* FIGURE 1 - Main stacked event studies (panels a-e)
*========================================================================

clear all
constraint drop _all

use analytic.dta, clear

* Create stacked sample and Wing corrective weights
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)

* Set up variables needed for wild bootstrap regressions
char event_time[omit] -1
xi i.event_time

gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp province_dum)
xtset panel_exp event_time


**************Figure 1a**************

wildbootstrap xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) errorweight(webb) coefficients(ecig_flavor) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_units_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) errorweight(webb) coefficients(1.treat#1.*Ievent_tim**) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt)) 

graph export "Output\Figure_1a_Log_Units.pdf", as(pdf) name("Graph") replace


**************Figure 1b**************

wildbootstrap xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_units_tob_unflav_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(1.treat#1.*Ievent_tim**) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_1b_Log_Units_Tobacco_Unflavored.pdf", as(pdf) name("Graph") replace


**************Figure 1c**************

wildbootstrap xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_units_flavored_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(1.treat#1.*Ievent_tim**) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-15(5)5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_1c_Log_Units_Flavored.pdf", as(pdf) name("Graph") replace


**************Figure 1d**************

wildbootstrap xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_units_mint_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(1.treat#1.*Ievent_tim**) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-15(5)5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_1d_Log_Units_Mint.pdf", as(pdf) name("Graph") replace



********Stacked Event Study***************

constraint drop _all

use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1

* Never-treated provinces
replace GVAR = . if GVAR == 0

* Build stacked sample using standard stacked DiD weights
stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)

* Rename package weight for consistency with existing code
rename q_weight stack_weight

* Create dummy variables for event time
char event_time[omit] -1
xi i.event_time

* Set up stacked panel
gen event_time_fe = event_time + 22

egen panel_exp = group(sub_exp newid)

xtset panel_exp event_time_fe

wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)

local att1 = ATT[1,1]
local att2 : display %5.3f `att1'

local p1 = ATT[3,1]
local p2 : display %5.3f `p1'


constraint drop _all

wildbootstrap xtreg LnCigsPC NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.treat##i._I* i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(1.treat#1._Ievent_tim_*) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)

matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"


***********Figure 1e*************

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure 1e_Stacked_Log_Cigarettes.pdf", as(pdf) name("Graph") replace




* Preserve the Figure 1e estimates for Figure 4a (same regression).
matrix A_cig_fig4a = A
local cig_fig4a_att "`att2'"
local cig_fig4a_p "`p2'"

*========================================================================
* FIGURE 2 - Alternative sales measures, COVID exclusion, weighting
*========================================================================

****************Figure 2a: Stacked DD Point Estimates - Cigarette and E-Cigarette Sales**************************

use analytic.dta, clear

gen panel_id = province_dum

* Baseline Wing weights
preserve
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)
rename q_weight stack_weight
tempfile baseline_stack
save `baseline_stack'
restore

* Full population weights
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21) weighttype(pop_constant) popvar(pop)
rename q_weight pop_constant_weight
keep sub_exp province_dum time pop_constant_weight
tempfile pop_weights
save `pop_weights'

* Merge full population weights onto baseline stack
use `baseline_stack', clear
merge 1:1 sub_exp province_dum time using `pop_weights', nogen

* Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp panel_id)
xtset panel_exp event_time_fe

gen specification = mod(_n-1,8)+1

gen coef1 = .
gen ci_upper1 = .
gen ci_lower1 = .

gen coef2 = .
gen ci_upper2 = .
gen ci_lower2 = .


* Baseline
wildbootstrap xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 1
replace ci_lower1 = R[4,1] if specification == 1
replace ci_upper1 = R[5,1] if specification == 1

* Volume
wildbootstrap xtreg log_volume_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 2
replace ci_lower1 = R[4,1] if specification == 2
replace ci_upper1 = R[5,1] if specification == 2

* Nicotine
wildbootstrap xtreg log_nicotine_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 3
replace ci_lower1 = R[4,1] if specification == 3
replace ci_upper1 = R[5,1] if specification == 3

* Drop March-August 2020
wildbootstrap xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight] if time<27 | time>32, fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 4
replace ci_lower1 = R[4,1] if specification == 4
replace ci_upper1 = R[5,1] if specification == 4

* Full population weighted
wildbootstrap xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=pop_constant_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 5
replace ci_lower1 = R[4,1] if specification == 5
replace ci_upper1 = R[5,1] if specification == 5

* Cigarette specifications for Figure 2a
preserve
    use analytic_cig_google.dta, clear
    keep if AnalyticSamp == 1
    replace GVAR = . if GVAR == 0
    stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)
    rename q_weight stack_weight
    gen event_time_fe = event_time + 22
    egen panel_exp = group(sub_exp newid)
    xtset panel_exp event_time_fe

    * Baseline
    wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)
    matrix C = r(table)
    local cb6 = C[1,1]
    local cl6 = C[4,1]
    local cu6 = C[5,1]

    * Drop March-August 2020
    drop if Year == 2020 & M >=3 & M <= 8
    wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)
    matrix C = r(table)
    local cb7 = C[1,1]
    local cl7 = C[4,1]
    local cu7 = C[5,1]

    * Full population weighted, including provinces
    use analytic_cig_google.dta, clear
    replace GVAR = . if GVAR == 0
    gen panel_id = newid
    stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21) weighttype(pop_constant) popvar(Pop2022)
    gen event_time_fe = event_time + 22
    egen panel_exp = group(sub_exp newid)
    xtset panel_exp event_time_fe
    wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(panel_id) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(10)
    matrix C = r(table)
    local cb8 = C[1,1]
    local cl8 = C[4,1]
    local cu8 = C[5,1]
restore

replace coef2 = `cb6' if specification == 6
replace ci_lower2 = `cl6' if specification == 6
replace ci_upper2 = `cu6' if specification == 6

replace coef2 = `cb7' if specification == 7
replace ci_lower2 = `cl7' if specification == 7
replace ci_upper2 = `cu7' if specification == 7

replace coef2 = `cb8' if specification == 8
replace ci_lower2 = `cl8' if specification == 8
replace ci_upper2 = `cu8' if specification == 8

duplicates drop specification, force

twoway (scatter coef1 specification if inlist(specification, 1, 2, 3, 4, 5), msize(medium) msymbol(circle) color(navy)) (rcap ci_lower1 ci_upper1 specification if inlist(specification, 1, 2, 3, 4, 5), color(navy) lwidth(medium)) (scatter coef2 specification if inlist(specification, 6, 7, 8), msize(medium) msymbol(triangle) color(maroon)) (rcap ci_lower2 ci_upper2 specification if inlist(specification, 6, 7, 8), color(maroon) lwidth(medium)), xlabel(1 "Baseline" 2 "Volume" 3 "Nicotine" 4 "Drop Mar.- Aug. 2020" 5 "Full Pop. Weighted" 6 "Baseline" 7 "Drop Mar.- Aug. 2020" 8 "Pop. Weighted (All Provinces)", angle(28) labsize(small) nogrid) ylabel(-1(0.2)0.4, grid) ytitle("Coefficient Estimate", size(medsmall)) xtitle("", size(small)) yline(0, lcolor(black) lpattern(dash)) scale(1.2) xscale(range(0 9)) legend(order(1 "ln(NVP Unit Sales/Capita)" 3 "ln(Cigarette Sales/Capita)") position(6) cols(2) region(style(none))) graphregion(margin(0 2 2 0))
graph export "Output\Figure_2a_Point_Estimates_Sales_log.pdf", as(pdf) name("Graph") replace


*************Figure 2b: Stacked DD Point Estimates*************

use analytic.dta, clear

gen panel_id = province_dum

* Baseline Wing weights
preserve
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)
rename q_weight stack_weight
tempfile baseline_stack
save `baseline_stack'
restore

* Full population weights
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21) weighttype(pop_constant) popvar(pop)
rename q_weight pop_constant_weight
keep sub_exp province_dum time pop_constant_weight
tempfile pop_weights
save `pop_weights'

* Merge full population weights onto baseline stack
use `baseline_stack', clear
merge 1:1 sub_exp province_dum time using `pop_weights', nogen

* Create dummy variables for event-time
char event_time[omit] -1
xi i.event_time

gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp panel_id)
xtset panel_exp event_time_fe

gen specification = mod(_n-1,15)+1

gen coef1 = .
gen ci_upper1 = .
gen ci_lower1 = .

gen coef2 = .
gen ci_upper2 = .
gen ci_lower2 = .

gen coef3 = .
gen ci_upper3 = .
gen ci_lower3 = .


* Flavored non-mentholated: Baseline
wildbootstrap xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 1
replace ci_lower1 = R[4,1] if specification == 1
replace ci_upper1 = R[5,1] if specification == 1

* Flavored non-mentholated: Volume
wildbootstrap xtreg log_volume_flav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 2
replace ci_lower1 = R[4,1] if specification == 2
replace ci_upper1 = R[5,1] if specification == 2

* Flavored non-mentholated: Nicotine
wildbootstrap xtreg log_nicotine_flav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 3
replace ci_lower1 = R[4,1] if specification == 3
replace ci_upper1 = R[5,1] if specification == 3

* Flavored non-mentholated: Drop March-August 2020
wildbootstrap xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight] if time<27 | time>32, fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 4
replace ci_lower1 = R[4,1] if specification == 4
replace ci_upper1 = R[5,1] if specification == 4

* Flavored non-mentholated: Full population weighted
wildbootstrap xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=pop_constant_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef1 = R[1,1] if specification == 5
replace ci_lower1 = R[4,1] if specification == 5
replace ci_upper1 = R[5,1] if specification == 5


* Mentholated: Baseline
wildbootstrap xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef2 = R[1,1] if specification == 6
replace ci_lower2 = R[4,1] if specification == 6
replace ci_upper2 = R[5,1] if specification == 6

* Mentholated: Volume
wildbootstrap xtreg log_volume_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef2 = R[1,1] if specification == 7
replace ci_lower2 = R[4,1] if specification == 7
replace ci_upper2 = R[5,1] if specification == 7

* Mentholated: Nicotine
wildbootstrap xtreg log_nicotine_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef2 = R[1,1] if specification == 8
replace ci_lower2 = R[4,1] if specification == 8
replace ci_upper2 = R[5,1] if specification == 8

* Mentholated: Drop March-August 2020
wildbootstrap xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight] if time<27 | time>32, fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef2 = R[1,1] if specification == 9
replace ci_lower2 = R[4,1] if specification == 9
replace ci_upper2 = R[5,1] if specification == 9

* Mentholated: Full population weighted
wildbootstrap xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=pop_constant_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef2 = R[1,1] if specification == 10
replace ci_lower2 = R[4,1] if specification == 10
replace ci_upper2 = R[5,1] if specification == 10


* Tobacco & unflavored: Baseline
wildbootstrap xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef3 = R[1,1] if specification == 11
replace ci_lower3 = R[4,1] if specification == 11
replace ci_upper3 = R[5,1] if specification == 11

* Tobacco & unflavored: Volume
wildbootstrap xtreg log_volume_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef3 = R[1,1] if specification == 12
replace ci_lower3 = R[4,1] if specification == 12
replace ci_upper3 = R[5,1] if specification == 12

* Tobacco & unflavored: Nicotine
wildbootstrap xtreg log_nicotine_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef3 = R[1,1] if specification == 13
replace ci_lower3 = R[4,1] if specification == 13
replace ci_upper3 = R[5,1] if specification == 13

* Tobacco & unflavored: Drop March-August 2020
wildbootstrap xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight] if time<27 | time>32, fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef3 = R[1,1] if specification == 14
replace ci_lower3 = R[4,1] if specification == 14
replace ci_upper3 = R[5,1] if specification == 14

* Tobacco & unflavored: Full population weighted
wildbootstrap xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=pop_constant_weight], fe cluster(panel_id) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
replace coef3 = R[1,1] if specification == 15
replace ci_lower3 = R[4,1] if specification == 15
replace ci_upper3 = R[5,1] if specification == 15


duplicates drop specification, force

twoway (scatter coef1 specification if inrange(specification,1,5), msize(medium) msymbol(circle) color(navy)) (rcap ci_lower1 ci_upper1 specification if inrange(specification,1,5), color(navy) lwidth(medium)) (scatter coef2 specification if inrange(specification,6,10), msize(medium) msymbol(triangle) color(green)) (rcap ci_lower2 ci_upper2 specification if inrange(specification,6,10), color(green) lwidth(medium)) (scatter coef3 specification if inrange(specification,11,15), msize(small) msymbol(diamond) color(maroon)) (rcap ci_lower3 ci_upper3 specification if inrange(specification,11,15), color(maroon) lwidth(medium)), xlabel(1 "Baseline" 2 "Volume" 3 "Nicotine" 4 "Drop Mar.- Aug. 2020" 5 "Full Pop. Weighted" 6 "Baseline" 7 "Volume" 8 "Nicotine" 9 "Drop Mar.- Aug. 2020" 10 "Full Pop. Weighted" 11 "Baseline" 12 "Volume" 13 "Nicotine" 14 "Drop Mar.- Aug. 2020" 15 "Full Pop. Weighted", angle(28) labsize(small) nogrid) ylabel(-14(2)4, grid) yscale(range(-14.5 5)) ytitle("Coefficient Estimate", size(medsmall)) xtitle("", size(small)) yline(0, lcolor(black) lpattern(dash)) scale(1.2) xscale(range(0 16)) legend(order(1 "ln(Flavored Non-Mentholated Units/Capita)" 3 "ln(Mentholated Units/Capita)" 5 "ln(Tobacco & Unflavored Units/Capita)") position(6) cols(1) region(style(none))) graphregion(margin(0 2 2 0))
graph export "Output\Figure_2b_Stacked_Point_Estimates_Flavors.pdf", as(pdf) name("Graph") replace

*========================================================================
* FIGURE 3 - Leave-one-adopter-out (panels a-e)
*========================================================================

****************Figure 3: Leave-One-Province/Group-Out****************

local outcomes log_units_per_capita log_units_flavored_per_capita log_units_mint_per_capita log_units_tob_unflav_per_capita units_per_capita units_flavored_per_capita units_mint_per_capita units_tob_unflav_per_capita

* Identify treated province/groups
use analytic.dta, clear
levelsof province_dum if inlist(province,"BC","MB & SK","Maritimes","ON"), local(plist)
local drops 0 `plist'

* Store results
tempname results
tempfile loo_results
postfile `results' str40 outcome str20 dropped double coef ci_lower ci_upper using `loo_results', replace

foreach p of local drops {

    use analytic.dta, clear

    if `p' == 0 {
        local dropped_name "Baseline"
    }
    else {
        quietly levelsof province if province_dum == `p', local(dropped_name) clean
        drop if province_dum == `p'
    }

    * Rebuild stacked sample and weights
    stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)
    rename q_weight stack_weight

    gen event_time_fe = event_time + 22
    egen panel_exp = group(sub_exp province_dum)
    xtset panel_exp event_time_fe

    foreach y of local outcomes {

        display as text _newline "******** Outcome: `y' | Dropped: `dropped_name' ********"

        wildbootstrap xtreg `y' ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

        matrix R = r(table)
        post `results' ("`y'") ("`dropped_name'") (R[1,1]) (R[4,1]) (R[5,1])
    }
}

postclose `results'

use `loo_results', clear

* Order: baseline, then treated clusters
gen order = .
replace order = 1 if dropped == "Baseline"
replace order = 2 if dropped == "BC"
replace order = 3 if dropped == "MB & SK"
replace order = 4 if dropped == "Maritimes"
replace order = 5 if dropped == "ON"


****************Figure 3a: Total NVP Sales****************

twoway ///
(scatter coef order if outcome=="log_units_per_capita" & dropped=="Baseline", msize(medium) msymbol(circle) color(black)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_per_capita" & dropped=="Baseline", color(black) lwidth(medium)) ///
(scatter coef order if outcome=="log_units_per_capita" & dropped!="Baseline", msize(medium) msymbol(circle) color(navy)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_per_capita" & dropped!="Baseline", color(navy) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "Drop British Columbia*" 3 "Drop Manitoba & {bf:Saskatchewan}*^" 4 "Drop Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 5 "Drop Ontario*^", angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("") ///
ylabel(-5(1)4, grid) ///
yscale(range(-5 4)) ///
xscale(range(.5 5.5)) ///
yline(0, lcolor(black) lpattern(dash)) ///
legend(off) ///
scale(1.2) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_3a_Leave_One_Adopter_Out.pdf", as(pdf) name("Graph") replace


****************Figure 3b: Tobacco & Unflavored NVP Sales****************

twoway ///
(scatter coef order if outcome=="log_units_tob_unflav_per_capita" & dropped=="Baseline", msize(medium) msymbol(diamond) color(black)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_tob_unflav_per_capita" & dropped=="Baseline", color(black) lwidth(medium)) ///
(scatter coef order if outcome=="log_units_tob_unflav_per_capita" & dropped!="Baseline", msize(medium) msymbol(diamond) color(maroon)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_tob_unflav_per_capita" & dropped!="Baseline", color(maroon) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "Drop British Columbia*" 3 "Drop Manitoba & {bf:Saskatchewan}*^" 4 "Drop Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 5 "Drop Ontario*^", angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("") ///
ylabel(-5(1)4, grid) ///
yscale(range(-4 4)) ///
xscale(range(.5 5.5)) ///
yline(0, lcolor(black) lpattern(dash)) ///
legend(off) ///
scale(1.2) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_3b_Leave_One_Adopter_Out_Tobacco_Unflavored.pdf", as(pdf) name("Graph") replace


****************Figure 3c: Flavored Non-Mentholated NVP Sales****************

twoway ///
(scatter coef order if outcome=="log_units_flavored_per_capita" & dropped=="Baseline", msize(medium) msymbol(circle) color(black)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_flavored_per_capita" & dropped=="Baseline", color(black) lwidth(medium)) ///
(scatter coef order if outcome=="log_units_flavored_per_capita" & dropped!="Baseline", msize(medium) msymbol(circle) color(navy)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_flavored_per_capita" & dropped!="Baseline", color(navy) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "Drop British Columbia*" 3 "Drop Manitoba & {bf:Saskatchewan}*^" 4 "Drop Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 5 "Drop Ontario*^", angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("") ///
ylabel(-20(5)15, grid) ///
yscale(range(-20 15)) ///
xscale(range(.5 5.5)) ///
yline(0, lcolor(black) lpattern(dash)) ///
legend(off) ///
scale(1.2) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_3c_Leave_One_Adopter_Out_Flavored.pdf", as(pdf) name("Graph") replace

****************Figure 3d: Mentholated NVP Sales****************

twoway ///
(scatter coef order if outcome=="log_units_mint_per_capita" & dropped=="Baseline", msize(medium) msymbol(triangle) color(black)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_mint_per_capita" & dropped=="Baseline", color(black) lwidth(medium)) ///
(scatter coef order if outcome=="log_units_mint_per_capita" & dropped!="Baseline", msize(medium) msymbol(triangle) color(green)) ///
(rcap ci_lower ci_upper order if outcome=="log_units_mint_per_capita" & dropped!="Baseline", color(green) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "Drop British Columbia*" 3 "Drop Manitoba & {bf:Saskatchewan}*^" 4 "Drop Maritimes ({bf:NB}, {bf:NS}, {bf:PEI})" 5 "Drop Ontario*^", angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("") ///
xscale(range(.5 5.5)) ///
ylabel(-20(5)15, grid) ///
yscale(range(-20 15)) ///
yline(0, lcolor(black) lpattern(dash)) ///
legend(off) ///
scale(1.2) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_3d_Leave_One_Adopter_Out_Mentholated.pdf", as(pdf) name("Graph") replace




********Figure 3e: Leave-One-Adopter-Out - Cigarette Sales********

* Identify treated provinces
use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1
levelsof newid if inlist(Prov,"BC","SK","NB","NS","ON"), local(plist)
local drops 0 `plist'

* Store results
tempname results
tempfile loo_cig
postfile `results' str20 dropped double coef ci_lower ci_upper using `loo_cig', replace

foreach p of local drops {

    use analytic_cig_google.dta, clear
    keep if AnalyticSamp == 1
    replace GVAR = . if GVAR == 0

    if `p' == 0 {
        local dropped_name "Baseline"
    }
    else {
        quietly levelsof Prov if newid == `p', local(dropped_name) clean
        drop if newid == `p'
    }

    display as text _newline "******** Dropped: `dropped_name' ********"

    * Rebuild stacked sample and weights
    stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)
    rename q_weight stack_weight

    gen event_time_fe = event_time + 22
    egen panel_exp = group(sub_exp newid)
    xtset panel_exp event_time_fe

    wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

    matrix R = r(table)
    post `results' ("`dropped_name'") (R[1,1]) (R[4,1]) (R[5,1])
}

postclose `results'

use `loo_cig', clear

* Plotting order
gen order = .
replace order = 1 if dropped == "Baseline"
replace order = 2 if dropped == "BC"
replace order = 3 if dropped == "SK"
replace order = 4 if dropped == "NB"
replace order = 5 if dropped == "NS"
replace order = 6 if dropped == "ON"

sort order

twoway ///
(scatter coef order if dropped=="Baseline", msize(medium) msymbol(triangle) color(black)) ///
(rcap ci_lower ci_upper order if dropped=="Baseline", color(black) lwidth(medium)) ///
(scatter coef order if dropped!="Baseline", msize(medium) msymbol(triangle) color(maroon)) ///
(rcap ci_lower ci_upper order if dropped!="Baseline", color(maroon) lwidth(medium)), ///
xlabel(1 "Baseline" 2 "Drop British Columbia*" 3 "Drop Saskatchewan*^" 4 "Drop New Brunswick" 5 "Drop Nova Scotia" 6 "Drop Ontario*^", angle(28) labsize(small) nogrid) ///
ylabel(, grid) ///
ytitle("Coefficient Estimate", size(medsmall)) ///
xtitle("") ///
xscale(range(.5 6.5)) ///
yline(0, lcolor(black) lpattern(dash)) ///
legend(off) ///
scale(1.2) ///
graphregion(margin(0 2 2 0))

graph export "Output\Figure_3e_Cigarette_Leave_One_Adopter_Out.pdf", as(pdf) name("Graph") replace

*========================================================================
* FIGURE 4 - Alternative cigarette event studies (panels a-d)
*========================================================================

* Restore the cigarette event-study estimates from Figure 1e.
matrix A = A_cig_fig4a
local att2 "`cig_fig4a_att'"
local p2 "`cig_fig4a_p'"
***********Figure 4a************

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") ylabel(-0.4(0.1)0.5) graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_4a_Stacked_Log_Cigarettes.pdf", as(pdf) name("Graph") replace



**********Figure 4b: TWFE*********************

use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1
keep if Year >= 2018
drop if Year == 2018 & M < 7

xtset newid YM


**************** ATT ****************

constraint drop _all

wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML UnEmp CvdDeathsPC AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions i.YM, fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)

local att1 = ATT[1,1]
local att2 : display %4.3f `att1'

local p1 = ATT[3,1]
local p2 : display %4.3f `p1'


**************** Event Study ****************

gen ttt = timeToTreat

* Shift event time so -1 is the omitted category
replace timeToTreat = timeToTreat + 38
replace timeToTreat = 37 if timeToTreat == .

* Event-time coefficients from -21 through +21, omitting -1
local escoefs

forvalues e = -21/21 {
    if `e' != -1 {
        local k = `e' + 38
        local escoefs `escoefs' `k'.timeToTreat
    }
}

constraint drop _all

wildbootstrap xtreg LnCigsPC ib37.timeToTreat NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML UnEmp CvdDeathsPC AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions i.YM, fe cluster(newid) coefficients(`escoefs') errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)

matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-0.4(0.1)0.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))


graph export "Output\Figure_4b_TWFE_Log_Cigarettes.pdf", as(pdf) name("Graph") replace


*********Figure 4c: SDID Event Study************
use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1
keep if Year >= 2018
drop if Year == 2018 & M < 7
replace ENDSFlvPol = 1 if ENDSFlvPol > 0

gen ttt = timeToTreat
gen coef = . 
gen ci_lower = .
gen ci_upper = .

********** Synthetic DID Event Study **********
sdid_event LnCigsPC newid YM ENDSFlvPol,placebo(all) covariates(NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions CvdDeathsPC UnEmp) combine(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22) vce(bootstrap) brep(10000)

* ATT


local att1 = e(H_comb)[1,1]
local att2 : display %4.3f `att1'

* Standard error
local se1  = e(H_comb)[1,2]
local se2 : display %4.3f `se1'

* Two-sided p-value
local p1 = 2*normal(-abs(`att1'/`se1'))

if `p1' < 0.001 {
    local p2 "<0.001"
}
else {
    local p2 : display %4.3f `p1'
}

display "ATT = `att2'"
display "SE = `se2'"
display "p-value = `p2'"

forvalues i = 2/40 {
    replace coef = e(H)[`i', 1]      if ttt == (`i'-2)
    replace ci_lower = e(H)[`i', 3]  if ttt == (`i'-2)
    replace ci_upper = e(H)[`i', 4]  if ttt == (`i'-2)
}

forvalues i = 41/78 {
    local ttt = `i' - 40
    replace coef     = e(H)[`i', 1] if ttt == -`ttt'
    replace ci_lower = e(H)[`i', 3] if ttt == -`ttt'
    replace ci_upper = e(H)[`i', 4] if ttt == -`ttt'
}

drop if ttt > 21
drop if ttt < -21

duplicates drop ttt, force

sort ttt

mkmat coef ci_lower ci_upper, matrix(S)
matrix A = S'

matrix colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-0.4(0.1)0.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_4c_SDID_Log_Cigarettes.pdf", as(pdf) name("Graph") replace







* Restore the original stacked cigarette sample after the SDID model.
constraint drop _all
use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1
replace GVAR = . if GVAR == 0
stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)
rename q_weight stack_weight
char event_time[omit] -1
xi i.event_time
gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp newid)
xtset panel_exp event_time_fe

*********** Figure 4d: Cigarette Sales Levels *********

* Pre-treatment mean
sum CigsPC if timeToTreat < 0 & timeToTreat > -13
sum CigsPC if timeToTreat < 0 & timeToTreat > -4
sum CigsPC if timeToTreat == -1


wildbootstrap xtreg CigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)

local att1 = ATT[1,1]
local att2 : display %5.3f `att1'

local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg CigsPC NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.treat##i._I* i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(1.treat#1._Ievent_tim_*) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)

matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"


coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_4d_Stacked_Cigarettes.pdf", as(pdf) name("Graph") replace

*========================================================================
* FIGURE 5 - Google Trends (panels a-b)
*========================================================================

*****************Figure 5: Stacked Google Trends************************

clear all
constraint drop _all

use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1 & merge_gt == 3
keep if inrange(YM, tm(2018m7), tm(2023m6))
replace GVAR = . if GVAR == 0

gen log_shopping = ln(shopping)
gen log_interest = ln(interest)


* Create stacked sample using standard Wing corrective weights
stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)

rename q_weight stack_weight

* Create event-time indicators
char event_time[omit] -1
xi i.event_time

gen event_time_fe = event_time + 22

egen panel_exp = group(sub_exp newid)
xtset panel_exp event_time_fe

******** Figure 5a: Google Shopping Searches **********

wildbootstrap xtreg log_shopping ENDSFlvPol CigTax ENDSTax_Perc ENDSTax_PerML NicCap20mgmL AtlBubblePanel UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)

local att1 = ATT[1,1]
local att2 : display %5.3f `att1'

local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_shopping CigTax ENDSTax_Perc ENDSTax_PerML NicCap20mgmL AtlBubblePanel UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(1.treat#1._Ievent_tim_*) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)

matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-1.5(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_5a_Stacked_Log_Shopping.pdf", as(pdf) name("Graph") replace



******** Figure 5b: Google Search Vape Shop ************

wildbootstrap xtreg log_interest ENDSFlvPol CigTax ENDSTax_Perc ENDSTax_PerML NicCap20mgmL AtlBubblePanel UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)

local att1 = ATT[1,1]
local att2 : display %5.3f `att1'

local p1 = ATT[3,1]
local p2 : display %5.3f `p1'


wildbootstrap xtreg log_interest CigTax ENDSTax_Perc ENDSTax_PerML NicCap20mgmL AtlBubblePanel UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(1.treat#1._Ievent_tim_*) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)

matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-1.5(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_5b_Stacked_Log_vapeshop.pdf", as(pdf) name("Graph") replace

*========================================================================
* TABLE 1 - Summary statistics (NVP, then cigarette)
*========================================================================

******************Table 1: E-Cigarette Summary Statistics********************
eststo clear
use analytic.dta, clear 
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




******Table 1: Summary Stats**************
eststo clear
use analytic_cig_google.dta, clear 
keep if AnalyticSamp == 1
keep if Year >= 2018
drop if Year == 2018 & M<7
drop if Year == 2023 & M>6

eststo full: estpost sum CigsPC
keep if Year == 2018 | Year == 2019 | Year == 2022 | Year == 2023
drop if Year == 2019 & M>6
drop if Year == 2022 & M<7

eststo pre_control: estpost sum CigsPC if First12M == 1 & EvFlvPolENDS==0
eststo post_control: estpost sum CigsPC if Last12M == 1 & EvFlvPolENDS==0
eststo pre_treated: estpost sum CigsPC if First12M == 1 & EvFlvPolENDS==1
eststo post_treated: estpost sum CigsPC if Last12M == 1 & EvFlvPolENDS==1

esttab full pre_control post_control pre_treated post_treated using "Output\summary_stats_cigarettes.html", ///
    replace html ///
    cells("mean(fmt(1)) sd(fmt(1)) N(fmt(0))") ///
    label

regress CigsPC i.Last12M  i.EvFlvPolENDS i.Last12M#i.EvFlvPolENDS

*========================================================================
* TABLE 2 - Baseline stacked DID estimates
*========================================================================

* The five baseline effects were estimated above in Figure 1a-e.
* Reproduce the original cigarette table export with the same stacked sample.
use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1
replace GVAR = . if GVAR == 0
stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)
rename q_weight stack_weight
gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp newid)
xtset panel_exp event_time_fe

*********Estimates in Figure 3a************
wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions CvdDeathsPC UnEmp i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
matrix wildp = e(b)
local c = colnumb(wildp, "ENDSFlvPol")
matrix wildp[1,`c'] = R[3,1]
estadd matrix wildp = wildp
estimates store cig_results1_1

esttab cig_results1_1 using "Output\cig_results.html", replace html label cells("b(star pvalue(wildp) fmt(3)) wildp(par fmt(3))") stats(N, labels("N") fmt(0)) star(* 0.10 ** 0.05 *** 0.01) keep(ENDSFlvPol)

*========================================================================
* TABLE 3 - Alternative models (stacked DID, TWFE, SDID)
*========================================================================

**********Table 3 (Rows 1 and 4) **********
clear all
constraint drop _all
eststo clear

use analytic.dta, clear

* Create stacked sample and Wing corrective weights
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)

* Set up variables needed for wild bootstrap regressions
char event_time[omit] -1
xi i.event_time

gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp province_dum)
xtset panel_exp event_time
gen stack_weight = q_weight

********** Log Outcomes **********
* All NVPs
wildbootstrap xtreg log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum log_units_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m1

* Flavored, non-mentholated
wildbootstrap xtreg log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum log_units_flavored_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m2

* Tobacco & unflavored
wildbootstrap xtreg log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum log_units_tob_unflav_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m3

* Mentholated
wildbootstrap xtreg log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum log_units_mint_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m4


********** Level Outcomes **********

* All NVPs
wildbootstrap xtreg units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

sum units_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m5

* Flavored, non-mentholated
wildbootstrap xtreg units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum units_flavored_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m6

* Tobacco & unflavored
wildbootstrap xtreg units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum units_tob_unflav_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m7

* Mentholated
wildbootstrap xtreg units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

quietly sum units_mint_per_capita if ttt_flavor < 0 & ttt_flavor > -13

estadd scalar wb_p = `p'
estadd scalar premean = r(mean)
estadd matrix wildp = wildp
eststo m8

esttab m1 m2 m3 m4 m5 m6 m7 m8 using "Output\Stacked_NVP_Results.html", replace ///
    keep(ecig_flavor) ///
    cells("b(star pvalue(wildp) fmt(3))") ///
    stats(wb_p premean, fmt(3 3) labels("Wild bootstrap p-value" "Pre-treatment mean")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("All NVPs (log)" "Flavored (log)" "Tobacco & Unflavored (log)" "Mentholated (log)" "All NVPs (levels)" "Flavored (levels)" "Tobacco & Unflavored (levels)" "Mentholated (levels)") ///
    html


****************Table 3 (Row 2): TWFE Estimates**************************
constraint drop _all
eststo clear

use analytic.dta, clear

drop if year == 2018 & month < 7
drop if year == 2023 & month > 6


********** All NVPs **********
wildbootstrap regress log_units_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

estadd scalar wb_p = `p'
estadd matrix wildp = wildp
eststo m1


********** Flavored, Non-Mentholated **********
wildbootstrap regress log_units_flavored_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

estadd scalar wb_p = `p'
estadd matrix wildp = wildp
eststo m2

********** Tobacco & Unflavored **********
wildbootstrap regress log_units_tob_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

estadd scalar wb_p = `p'
estadd matrix wildp = wildp
eststo m3

********** Mentholated **********
wildbootstrap regress log_units_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.province_dum i.time, cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix R = r(table)
local p = R[3,1]

matrix wildp = e(b)
local c = colnumb(wildp,"ecig_flavor")
matrix wildp[1,`c'] = `p'

estadd scalar wb_p = `p'
estadd matrix wildp = wildp
eststo m4


********** Export HTML Table **********

esttab m1 m2 m3 m4 using "Output\Table_3_Row_2_TWFE_NVP_Results.html", replace ///
    keep(ecig_flavor) ///
    cells("b(star pvalue(wildp) fmt(3))") ///
    stats(wb_p, fmt(3) labels("Wild bootstrap p-value")) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("All NVPs" "Flavored, Non-Mentholated" "Tobacco & Unflavored" "Mentholated") ///
    nonotes ///
    html

	
******Table 3 (Row 3) Synthetic DID Estimates*****************

use analytic.dta, clear

drop if year == 2018 & month < 7
drop if year == 2023 & month > 6
	
capture drop ecig_flavor_intensity ecig_flavor_sdid first_flavor event_flavor

gen double ecig_flavor_intensity = ecig_flavor
gen byte ecig_flavor_sdid = (ecig_flavor_intensity > 0) if !missing(ecig_flavor_intensity)

bysort province_dum: egen first_flavor = min(cond(ecig_flavor_sdid == 1, time, .))
gen event_flavor = time - first_flavor if first_flavor < .

bysort province_dum: egen double fullmonth_intensity = max(cond(event_flavor == 1, ecig_flavor_intensity, .))
replace ecig_flavor_intensity = fullmonth_intensity if event_flavor == 0 & !missing(fullmonth_intensity)
drop fullmonth_intensity

local covars cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions
local combine 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22

local outcomes log_units_per_capita log_units_flavored_per_capita log_units_tob_unflav_per_capita log_units_mint_per_capita

matrix SDID_results = J(4,7,.)
matrix rownames SDID_results = All_NVPs Flavored_NonMenthol Tobacco_Unflavored Mentholated
matrix colnames SDID_results = Exposure ATT_Raw ATT_Scaled SE_Scaled LB_Scaled UB_Scaled P_Value

set seed 1000

local row = 1

foreach y of local outcomes {

    quietly summarize ecig_flavor_intensity if inrange(event_flavor,0,21) & !missing(`y'), meanonly
    local exposure = r(mean)

    sdid_event `y' province_dum time ecig_flavor_sdid, ///
        combine(`combine') ///
        covariates(`covars') ///
        vce(bootstrap) ///
        brep(10000)

    matrix H = e(H_comb)

    local att_raw = H[1,1]
    local se_raw  = H[1,2]
    local lb_raw  = H[1,3]
    local ub_raw  = H[1,4]

    local att_scaled = `att_raw' / `exposure'
    local se_scaled  = `se_raw'  / `exposure'
    local lb_scaled  = `lb_raw'  / `exposure'
    local ub_scaled  = `ub_raw'  / `exposure'

    local p = 2*normal(-abs(`att_scaled'/`se_scaled'))

    matrix SDID_results[`row',1] = `exposure'
    matrix SDID_results[`row',2] = `att_raw'
    matrix SDID_results[`row',3] = `att_scaled'
    matrix SDID_results[`row',4] = `se_scaled'
    matrix SDID_results[`row',5] = `lb_scaled'
    matrix SDID_results[`row',6] = `ub_scaled'
    matrix SDID_results[`row',7] = `p'

    local row = `row' + 1
}

matrix list SDID_results, format(%9.3f)
	

	

*========================================================================
* APPENDIX FIGURE A1 - NVP sales trends
*========================================================================

**********Figure A1: NVP Sales Trends for Treatment and Control Groups************
use analytic.dta, clear 
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

*========================================================================
* APPENDIX FIGURE A2 - Cigarette sales trends
*========================================================================

******Figure A2:Sales Trends**************
use analytic_cig_google.dta, clear 
keep if AnalyticSamp == 1
drop if Year <2018
drop if Year == 2018 & M<7
drop if Year == 2023 & M>6

gen treated = 0 
replace treated = 1 if timeToTreat != . 

collapse (mean) CigsPC, by(YM treated)

bysort YM: egen treat_value = max(cond(treated == 1, CigsPC, .))
bysort YM: egen control_value = max(cond(treated == 0, CigsPC, .))

gen treated_higher = treat_value > control_value
preserve
bysort YM: keep if _n == 1

count if inrange(YM, ym(2021,9), ym(2023,6))
count if treated_higher == 1 & inrange(YM, ym(2021,9), ym(2023,6))
restore


gen time = YM

twoway (line CigsPC YM if treated == 1, color(maroon)) (line CigsPC YM if treated == 0, color(navy) lpattern(longdash)), xtitle("") ytitle("Cigarettes per Capita") xline(722.5 725.5 727.5 739.5) ylabel(0(20)80) xlabel(,nogrid) legend(order(1 "Treatment Provinces" 2 "Control Provinces") pos(6) cols(2)) text(83 722.3  "NS" 83 725.3  "ON" 83 727.4  "BC" 83 739.3  "NB & SK", place(left) color(black) size(small))
graph export "Output\Figure_A2_Sales_Trends_Cigarettes.pdf", as(pdf) name("Graph") replace

*========================================================================
* APPENDIX FIGURE A3 - Annual cigarette sales trends
*========================================================================

**********Figure A3 - Annual Cigarette Sales: Treatment vs. Control**********

use analytic_cig_google.dta, clear

keep if Territories==0 & Prov!="PE"

* Define treatment and control groups
gen treated_group = GVAR > 0

label define treatedlbl 0 "Non-Adopting Provinces" 1 "Adopting Provinces"
label values treated_group treatedlbl

* Keep complete calendar years only
keep if Year >= 2013 & Year <= 2022

* Annual cigarette sales per capita for each province
collapse (sum) CigsPC, by(Year Prov treated_group)

* Average annual sales per capita by treatment group
collapse (mean) CigsPC, by(Year treated_group)

* Natural log of annual sales per capita
gen lnCigsPC = ln(CigsPC)


* Compare treatment and control groups by year
preserve

keep Year treated_group lnCigsPC

reshape wide lnCigsPC, i(Year) j(treated_group)

gen gap = lnCigsPC0 - lnCigsPC1

format lnCigsPC0 lnCigsPC1 gap %7.3f

list Year lnCigsPC0 lnCigsPC1 gap, noobs clean

* Range of differences before 2020
summarize gap if inrange(Year, 2013, 2019)

display "Minimum gap = " %7.3f r(min)
display "Maximum gap = " %7.3f r(max)

restore


* Estimate pre-2018 linear trends
reg lnCigsPC Year if treated_group == 0 & Year < 2018
gen fit_control = _b[_cons] + _b[Year]*Year if treated_group == 0

reg lnCigsPC Year if treated_group == 1 & Year < 2018
gen fit_treat = _b[_cons] + _b[Year]*Year if treated_group == 1

* Split fitted trends into pre-period (solid) and extrapolated post-period (dashed)
gen fit_control_pre  = fit_control if treated_group == 0 & Year <= 2017
gen fit_control_post = fit_control if treated_group == 0 & Year >= 2017

gen fit_treat_pre    = fit_treat if treated_group == 1 & Year <= 2017
gen fit_treat_post   = fit_treat if treated_group == 1 & Year >= 2017

twoway ///
    (connected lnCigsPC Year if treated_group == 0, ///
        msymbol(circle) msize(medium) lwidth(medthick) ///
        color(navy) lcolor(navy)) ///
    (connected lnCigsPC Year if treated_group == 1, ///
        msymbol(triangle) msize(medium) lwidth(medthick) ///
        color(maroon) lcolor(maroon)) ///
    (line fit_control_pre Year if treated_group == 0, ///
        sort lcolor(eltblue) lwidth(medium) lpattern(solid)) ///
    (line fit_control_post Year if treated_group == 0, ///
        sort lcolor(eltblue) lwidth(medium) lpattern(dash)) ///
    (line fit_treat_pre Year if treated_group == 1, ///
        sort lcolor(cranberry) lwidth(medium) lpattern(solid)) ///
    (line fit_treat_post Year if treated_group == 1, ///
        sort lcolor(cranberry) lwidth(medium) lpattern(dash)), ///
    xline(2017.5, lcolor(black) lpattern(shortdash)) ///
    text(6.99 2017.55 "Federal NVP Legalization", place(e) size(medium) color(black)) ///
    xlabel(2013(1)2022, angle(45) nogrid) ///
    ylabel(, grid) ///
    xtitle("") ///
    ytitle("Ln(Average Cigarette Sales Per Capita)") ///
    legend(order(1 "Control Provinces" 2 "Treatment Provinces") ///
           rows(1) position(6)) ///
    graphregion(color(white))
graph export "Output\Figure_A3_Sales_Trends_Logs.pdf", as(pdf) name("Graph") replace

	

	

*========================================================================
* APPENDIX FIGURE A4 - NVP volume event studies (panels a-d)
*========================================================================

clear all
constraint drop _all

use analytic.dta, clear

* Create stacked sample and Wing corrective weights
stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)

* Set up variables needed for wild bootstrap regressions
char event_time[omit] -1
xi i.event_time

gen event_time_fe = event_time + 22
egen panel_exp = group(sub_exp province_dum)
xtset panel_exp event_time


**************Figure A4a**************

wildbootstrap xtreg log_volume_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) errorweight(webb) coefficients(ecig_flavor) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_volume_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) errorweight(webb) coefficients(1.treat#1.*Ievent_tim**) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt)) 

graph export "Output\Figure_1a_Log_Volume.pdf", as(pdf) name("Graph") replace


**************Figure A4b**************

wildbootstrap xtreg log_volume_unflav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_volume_unflav_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(1.treat#1.*Ievent_tim**) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-1(0.5)1.5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_1b_Log_Volume_Tobacco_Unflavored.pdf", as(pdf) name("Graph") replace


**************Figure A4c**************

wildbootstrap xtreg log_volume_flav_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_volume_flav_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(1.treat#1.*Ievent_tim**) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-15(5)5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_1c_Log_Volume_Flavored.pdf", as(pdf) name("Graph") replace


**************Figure A4d**************

wildbootstrap xtreg log_volume_mint_per_capita ecig_flavor cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

matrix ATT = r(table)
local att1 = ATT[1,1]
local att2 : display %5.3f `att1'
local p1 = ATT[3,1]
local p2 : display %5.3f `p1'

wildbootstrap xtreg log_volume_mint_per_capita cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions i.treat##i._I* i.sub_exp#i.event_time_fe [aw=q_weight], fe cluster(province_dum) coefficients(1.treat#1.*Ievent_tim**) errorweight(webb) reps(10000) rseed(1000)

matrix W = r(table)
matrix B  = W[1,1..20], [0], W[1,21..42]
matrix LL = W[4,1..20], [0], W[4,21..42]
matrix UL = W[5,1..20], [0], W[5,21..42]

matrix A = B \ LL \ UL

mat colnames A = "-21" "-20" "-19" "-18" "-17" "-16" "-15" "-14" "-13" "-12" "-11" "-10" "-9" "-8" "-7" "-6" "-5" "-4" "-3" "-2" "-1" "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18" "19" "20" "21"

coefplot matrix(A), ci((2 3)) vertical yline(0) xline(21.5) ylabel(-15(5)5) xtitle("Months to Flavor Restriction") ytitle("Estimated Coefficient") graphregion(color(white)) xlabel(2 "-20" 7 "-15" 12 "-10" 17 "-5" 22 "0" 27 "5" 32 "10" 37 "15" 42 "20") note("ATT: {&beta} = `att2'; p-value = `p2'", pos(6) size(12pt))

graph export "Output\Figure_1d_Log_Volume_Mint.pdf", as(pdf) name("Graph") replace

*========================================================================
* APPENDIX FIGURE A5 - Randomization inference (NVP, then cigarettes)
*========================================================================

**************Figure A5: Placebo Test - Two-Sided*****************

clear all
set more off

local kappa_pre = 21
local kappa_post = 21

local outcomes log_units_per_capita log_units_flavored_per_capita log_units_tob_unflav_per_capita log_units_mint_per_capita

local controls cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions


*===============================================================
* 1. Build actual stacked data once
*===============================================================

use analytic.dta, clear

stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(`kappa_pre') kpost(`kappa_post')

rename q_weight stack_weight

gen event_time_fe = event_time + `kappa_pre' + 1
egen panel_exp = group(sub_exp province_dum)
xtset panel_exp event_time_fe

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
postfile SUM str40 outcome double(actual_b actual_p pval_b n_placebos) using ri_summary_flavored_equal.dta, replace

foreach y of local outcomes {

    di as text "=================================================="
    di as result "Running outcome: `y'"
    di as text "=================================================="


    *===========================================================
    * Actual estimate + wild bootstrap p-value
    *===========================================================

    use `actual_stack', clear

    wildbootstrap xtreg `y' ecig_flavor `controls' i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(province_dum) coefficients(ecig_flavor) errorweight(webb) reps(10000) rseed(1000)

    matrix W = r(table)

    local actual_b = W[1,1]
    local actual_p = W[3,1]

    di as result "Actual beta = " %7.4f `actual_b'
    di as result "Wild bootstrap p-value = " %7.4f `actual_p'


    cap postclose PH
    postfile PH int iter double(beta) using placebo_results_`y'.dta, replace


    *===========================================================
    * 4. Placebo loop
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


            * Build placebo stack

            stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(`kappa_pre') kpost(`kappa_post')

            rename q_weight stack_weight

            gen event_time_fe = event_time + `kappa_pre' + 1
            egen panel_exp = group(sub_exp province_dum)
            xtset panel_exp event_time_fe


            * Placebo coefficient only

            cap xtreg `y' ecig_flavor `controls' i.sub_exp#i.event_time_fe [aw=stack_weight], fe

            if _rc == 0 & !missing(_b[ecig_flavor]) {
                local b = _b[ecig_flavor]
                post PH (`r') (`b')
            }
        }

        if mod(`r',25) == 0 {
            noi di as txt "Outcome `y': done " `r' " / " `nperm'
        }
    }

    postclose PH


    *===========================================================
    * 5. RI-beta equal-tailed two-sided p-value
    *===========================================================

    use placebo_results_`y'.dta, clear

    local total = _N
    di as text "Successful placebos for `y': `total'"

    * Upper tail

    count if beta >= `actual_b'
    local n_upper = r(N)

    * Lower tail

    count if beta <= `actual_b'
    local n_lower = r(N)

    * Include observed assignment in both inclusive tails

    local p_upper = (`n_upper' + 1) / (`total' + 1)
    local p_lower = (`n_lower' + 1) / (`total' + 1)

    * Equal-tailed two-sided p-value

    local pval_b = min(1, 2*min(`p_upper', `p_lower'))

    di as result "`y'"
    di as result "Wild bootstrap p-value = " %7.4f `actual_p'
    di as result "RI-beta upper-tail p-value = " %7.4f `p_upper'
    di as result "RI-beta lower-tail p-value = " %7.4f `p_lower'
    di as result "RI-beta equal-tailed p-value = " %7.4f `pval_b'

    post SUM ("`y'") (`actual_b') (`actual_p') (`pval_b') (`total')


    *===========================================================
    * 6. Graph
    *===========================================================

    twoway (histogram beta, frequency fcolor(navy%40) lcolor(navy)), xline(`actual_b', lcolor(red) lwidth(medthick)) xtitle("Placebo coefficient") xlabel(, nogrid) ytitle("Frequency") note("Red line = actual coefficient: `: di %5.3f `actual_b''; Wild bootstrap p-value = `: di %5.3f `actual_p''" "RI-beta p-value = `: di %5.3f `pval_b''", size(medium))

    graph export "Output\Figure_2_placebo_beta_equal_`y'.pdf", as(pdf) replace
}

postclose SUM

use ri_summary_flavored_equal.dta, clear
list, clean

	
	
clear all
***********Figure A5e: Placebo Test - Two-Tailed Equal P-Values*************

use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1

local kappa_pre = 21
local kappa_post = 21
local nreps = 5000
set seed 1000

replace GVAR = . if GVAR == 0


*===============================================================
* 1. Build actual stacked data
*===============================================================

stacked build, time(YM) unit(newid) adopt(GVAR) kpre(`kappa_pre') kpost(`kappa_post')

rename q_weight stack_weight

gen time_id = YM
gen panel_id = newid

sum panel_id time_id LnCigsPC treat post event_time sub_exp

preserve
    keep if event_time == 0
    gen N_treated = treat
    gen N_control = 1 - treat
    gen N_total = 1
    collapse (sum) N_treated N_control N_total, by(sub_exp)
    list sub_exp N_treated N_control N_total
restore

sumup stack_weight if treat == 0 & event_time == 0, by(sub_exp) s(mean)

char event_time[omit] -1
xi i.event_time

bysort event_time sub_exp treat: egen sub_exp_stack_weight = sum(stack_weight)
bysort event_time sub_exp treat: egen exp_arm_pop = sum(Pop2022)
gen pop_stack_weight = sub_exp_stack_weight * Pop2022/exp_arm_pop


*===============================================================
* 2. Actual estimate and wild-bootstrap p-value
*===============================================================

egen panel_exp = group(sub_exp newid)
gen event_time_fe = event_time + `kappa_pre' + 1

xtset panel_exp

wildbootstrap xtreg LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC i.sub_exp#i.event_time_fe [aw=stack_weight], fe cluster(newid) coefficients(ENDSFlvPol) errorweight(webb) reps(10000) rseed(1000)

matrix WB = r(table)

local actual_b = WB["b",1]
local actual_t = WB["t",1]
local actual_p = WB["pvalue",1]

di as result "Actual beta = " %7.4f `actual_b'
di as result "Actual t = " %6.3f `actual_t'
di as result "Wild-bootstrap p-value = " %7.4f `actual_p'

set seed 1000


*===============================================================
* 3. Generate province list
*===============================================================

preserve
    use analytic_cig_google.dta, clear
    keep if AnalyticSamp == 1
    bysort newid: keep if _n == 1
    keep newid
    sort newid
    mkmat newid, matrix(PROV)
restore

local nprov = rowsof(PROV)
di "Unique provinces: `nprov'"
di "Random permutations to run: `nreps'"


*===============================================================
* 4. Placebo loop with estimated completion time
*===============================================================

cap postclose PH
postfile PH int iter double(beta se tstat) using placebo_results_cigs.dta, replace

local start_ms = clock("`c(current_date)' `c(current_time)'", "DMYhms")

forvalues r = 1/`nreps' {

    qui {
        use analytic_cig_google.dta, clear
        keep if AnalyticSamp == 1
        replace GVAR = . if GVAR == 0

        *---- Build random province-level source map ----

        preserve
            clear
            set obs `nprov'

            gen long source_index = _n
            gen double u = runiform()

            gen long source_newid = .
            forvalues k = 1/`nprov' {
                local src_p = PROV[`k', 1]
                replace source_newid = `src_p' if source_index == `k'
            }

            sort u

            gen long target_index = _n
            gen long newid = .

            forvalues k = 1/`nprov' {
                local tgt_p = PROV[`k', 1]
                replace newid = `tgt_p' if target_index == `k'
            }

            keep newid source_newid
            tempfile pmap
            save `pmap', replace
        restore

        *---- Save source-province treatment histories ----

        preserve
            keep newid YM ENDSFlvPol GVAR
            rename newid source_newid
            rename ENDSFlvPol _ENDS_src
            rename GVAR _GVAR_src
            tempfile src_treat
            save `src_treat', replace
        restore

        *---- Apply placebo treatment histories ----

        merge m:1 newid using `pmap', nogen
        merge m:1 source_newid YM using `src_treat', nogen keep(match master)

        replace ENDSFlvPol = _ENDS_src
        replace GVAR = _GVAR_src

        drop _ENDS_src _GVAR_src source_newid


        *---- Build placebo stacked sample ----

        stacked build, time(YM) unit(newid) adopt(GVAR) kpre(`kappa_pre') kpost(`kappa_post')

        rename q_weight stack_weight

        gen panel_id = newid

        bysort event_time sub_exp treat: egen sub_exp_stack_weight = sum(stack_weight)
        bysort event_time sub_exp treat: egen exp_arm_pop = sum(Pop2022)
        gen pop_stack_weight = sub_exp_stack_weight * Pop2022/exp_arm_pop


        *---- Placebo coefficient ----

        cap reghdfe LnCigsPC ENDSFlvPol NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions UnEmp CvdDeathsPC [aw = stack_weight], cluster(panel_id) absorb(i.sub_exp#i.newid i.sub_exp#i.event_time)

        if _rc == 0 & !missing(_se[ENDSFlvPol]) & _se[ENDSFlvPol] > 0 {
            local b = _b[ENDSFlvPol]
            local s = _se[ENDSFlvPol]
            post PH (`r') (`b') (`s') (`b'/`s')
        }
    }

    *---- Progress and estimated completion time ----

    if mod(`r',25)==0 | `r'==`nreps' {

        local now_ms = clock("`c(current_date)' `c(current_time)'", "DMYhms")

        local elapsed_min = (`now_ms' - `start_ms')/60000
        local remaining_min = `elapsed_min'*(`nreps'-`r')/`r'
        local finish_ms = `now_ms' + `remaining_min'*60000
        local percent_done = 100*`r'/`nreps'

        noi di as txt "--------------------------------------------------"
        noi di as result "Completed: `r' / `nreps' (" %5.1f `percent_done' "%)"
        noi di as txt "Elapsed time:       " %7.1f `elapsed_min' " minutes"
        noi di as txt "Estimated remaining:" %7.1f `remaining_min' " minutes"
        noi di as txt "Expected completion: " %tcDDmonCCYY_HH:MM `finish_ms'
        noi di as txt "--------------------------------------------------"
    }
}

postclose PH


*===============================================================
* 5. RI-beta and RI-t equal-tailed p-values
*===============================================================

use placebo_results_cigs.dta, clear

sum beta, detail
sum tstat, detail

local total = _N
di as txt "Successful placebos: `total'"

* RI-beta: upper and lower tails

count if beta >= `actual_b'
local n_upper_b = r(N)

count if beta <= `actual_b'
local n_lower_b = r(N)

local p_upper_b = (`n_upper_b' + 1)/(`total' + 1)
local p_lower_b = (`n_lower_b' + 1)/(`total' + 1)

local pval_b = min(1, 2*min(`p_upper_b', `p_lower_b'))

* RI-t: upper and lower tails

count if tstat >= `actual_t'
local n_upper_t = r(N)

count if tstat <= `actual_t'
local n_lower_t = r(N)

local p_upper_t = (`n_upper_t' + 1)/(`total' + 1)
local p_lower_t = (`n_lower_t' + 1)/(`total' + 1)

local pval_t = min(1, 2*min(`p_upper_t', `p_lower_t'))

di as result "RI-beta p-value = " %7.4f `pval_b'
di as result "RI-t p-value = " %7.4f `pval_t'
di as result "Wild-bootstrap p-value = " %7.4f `actual_p'


*===============================================================
* 6. Graphs
*===============================================================

twoway (histogram beta, frequency fcolor(navy%40) lcolor(navy)), xline(`actual_b', lcolor(red) lwidth(medthick)) xtitle("Placebo coefficient") ytitle("Frequency") xlabel(,nogrid) note("Red line = actual coefficient: `: di %5.3f `actual_b''; Wild bootstrap p-value = `: di %5.3f `actual_p''" "RI-beta p-value = `: di %5.3f `pval_b''", size(medium))

graph export "Output\Figure_2_placebo_beta_cigs_equal.pdf", as(pdf) replace

twoway (histogram tstat, frequency fcolor(maroon%40) lcolor(maroon)), xline(`actual_t', lcolor(red) lwidth(medthick)) xtitle("Placebo t-stat") ytitle("Frequency") xlabel(,nogrid) note("Red line = actual t-stat: `: di %5.2f `actual_t''; Wild bootstrap p-value = `: di %5.3f `actual_p''" "RI-t p-value = `: di %5.3f `pval_t''", size(medium))

graph export "Output\Figure_2_placebo_tstat_cigs_equal.pdf", as(pdf) replace

*========================================================================
* APPENDIX TABLE A1 - Flavor restriction implementation dates
*========================================================================

* Treatment adoption dates are encoded in the data construction above.
* Table A1 in the manuscript lists these dates; no separate estimation is required.

*========================================================================
* APPENDIX TABLE A2 - Synthetic DID unit and time weights
*========================================================================

use analytic.dta, clear
drop if year == 2018 & month < 7
drop if year == 2023 & month > 6

********** Synthetic DID Weights **********
replace ecig_flavor = 1 if ecig_flavor>0

* All NVPs
sdid log_units_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(10) seed(10) returnweights generate(all_) mattitles

* Flavored, non-mentholated
sdid log_units_flavored_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(10) seed(10) returnweights generate(flav_) mattitles

* Tobacco & unflavored
sdid log_units_tob_unflav_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(10) seed(10) returnweights generate(tob_) mattitles

* Mentholated
sdid log_units_mint_per_capita province_dum time ecig_flavor, vce(bootstrap) graph covariates(cig_tax ENDSTax_Perc ENDSTax_PerML ecig_nicotine trade_bubble UnEmp CvdDeathsPC InternalMvmtRestrictions NonEssRetRestrictions) reps(10) seed(10) returnweights generate(mint_) mattitles


********** Unit Weights Table A2 **********

preserve

label variable province "Province"
label variable all_omega28 "All NVPs - Maritimes"
label variable all_omega31 "All NVPs - ON"
label variable all_omega33 "All NVPs - BC"
label variable all_omega45 "All NVPs - MB & SK"
label variable flav_omega28 "Flavored - Maritimes"
label variable flav_omega31 "Flavored - ON"
label variable flav_omega33 "Flavored - BC"
label variable flav_omega45 "Flavored - MB & SK"
label variable tob_omega28 "Tobacco & Unflavored - Maritimes"
label variable tob_omega31 "Tobacco & Unflavored - ON"
label variable tob_omega33 "Tobacco & Unflavored - BC"
label variable tob_omega45 "Tobacco & Unflavored - MB & SK"
label variable mint_omega28 "Mentholated - Maritimes"
label variable mint_omega31 "Mentholated - ON"
label variable mint_omega33 "Mentholated - BC"
label variable mint_omega45 "Mentholated - MB & SK"

keep province all_omega* flav_omega* tob_omega* mint_omega*

bysort province: keep if _n == 1
sort province

export excel using "Output\SDID_Weights.xlsx", ///
    sheet("Unit Weights") ///
    firstrow(varlabels) replace

restore


********** Time Weights Table **********

preserve

label variable time "Time"
label variable all_lambda28 "All NVPs - Maritimes"
label variable all_lambda31 "All NVPs - ON"
label variable all_lambda33 "All NVPs - BC"
label variable all_lambda45 "All NVPs - MB & SK"
label variable flav_lambda28 "Flavored - Maritimes"
label variable flav_lambda31 "Flavored - ON"
label variable flav_lambda33 "Flavored - BC"
label variable flav_lambda45 "Flavored - MB & SK"
label variable tob_lambda28 "Tobacco & Unflavored - Maritimes"
label variable tob_lambda31 "Tobacco & Unflavored - ON"
label variable tob_lambda33 "Tobacco & Unflavored - BC"
label variable tob_lambda45 "Tobacco & Unflavored - MB & SK"
label variable mint_lambda28 "Mentholated - Maritimes"
label variable mint_lambda31 "Mentholated - ON"
label variable mint_lambda33 "Mentholated - BC"
label variable mint_lambda45 "Mentholated - MB & SK"

keep time all_lambda* flav_lambda* tob_lambda* mint_lambda*

bysort time: keep if _n == 1
sort time

export excel using "Output\SDID_Weights.xlsx", ///
    sheet("Time Weights") ///
    firstrow(varlabels) sheetreplace

restore




use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1
keep if Year >= 2018
drop if Year == 2018 & M < 7
replace ENDSFlvPol = 1 if ENDSFlvPol > 0

********** Cigarette Unit Weights **********

sdid LnCigsPC newid YM ENDSFlvPol, covariates(NicCap20mgmL CigTax ENDSTax_Perc ENDSTax_PerML AtlBubblePanel InternalMvmtRestrictions NonEssRetRestrictions CvdDeathsPC UnEmp) vce(bootstrap) reps(3) returnweights

preserve
label variable Prov "Donor Province"
label variable omega723 "NS"
label variable omega726 "ON"
label variable omega728 "BC"
label variable omega740 "NB & SK"
keep Prov omega*
bysort Prov: keep if _n == 1
sort Prov

export excel using "Output\SDID_Weights.xlsx", ///
    sheet("Cigarette Unit Weights") ///
    firstrow(varlabels) sheetreplace

restore

********** Cigarette Time Weights **********

preserve
keep YM lambda*
bysort YM: keep if _n == 1
sort YM
export excel using "Output\SDID_Weights.xlsx", ///
    sheet("Cigarette Time Weights") ///
    firstrow(variables) sheetreplace
restore

*========================================================================
* ADDITIONAL DIAGNOSTICS - COVID deaths and policy correlation
*========================================================================

*************Covid deaths as percent of population******
constraint drop _all


use analytic_cig_google.dta, clear
keep if AnalyticSamp == 1

* Never-treated provinces
replace GVAR = . if GVAR == 0

* Build stacked sample using standard stacked DiD weights
stacked build, time(YM) unit(newid) adopt(GVAR) kpre(21) kpost(21)

duplicates drop Prov YM, force

* Monthly COVID deaths
gen monthly_deaths = TotDeathsThisMonth - TotDeathsPriorMonth

* Total deaths
egen total_deaths = total(monthly_deaths)

* Total population (count each province once)
egen tag = tag(Prov)
egen total_population = total(Pop2022 * tag)

* Deaths as percentage of population
gen death_pct = 100 * total_deaths / total_population

display "Total COVID deaths: " %12.0fc total_deaths[1]
display "Total population: " %12.0fc total_population[1]
display "COVID deaths (%): " %6.3f death_pct[1]

use analytic.dta, clear

stacked build, time(time) unit(province_dum) adopt(flavor_treat_period) kpre(21) kpost(21)

pwcorr ecig_flavor CvdDeathsPC [aw=q_weight], sig

capture log close
