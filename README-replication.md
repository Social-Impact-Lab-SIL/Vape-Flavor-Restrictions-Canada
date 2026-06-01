# Replication Package: [Insert Project Title]

This folder contains the code and instructions to replicate the findings of "Restricting Sales of Flavored Nicotine Vaping Products: Effects on Nicotine Vaping Product and Cigarette Sales in Canada". Currently under review.

## Data Availability Statement
- **Raw Data:** NVP sales and cigarette sales are proprietary from NielsenIQ and Health Canada. Google Trends and covariates are provided in this repo.
- **Data Access:** For access to NVP and cigarette sales, contact Health Canada.
- **Note:** If using restricted data, the scripts provided here assume you have placed the raw files in the `/data` folder.

## Software Requirements
- **Primary Software:** Stata 18.1 or greater
- **Required Packages/Libraries:** - Stata: `ssc install reghdfe`, `ssc install ftools`, `ssc install sdid`, `ssc install sdid_event`

## Instructions
1. **Set Directory:** Open `main_file.do` (or `.R`) and update the `global` or `working_directory` path to your local machine.
2. **Run Analysis:** Execute the scripts in the following order:
   - `NVP_Code.do`
   - `Cigarette_Code.do`
3. **Estimated Run Time:** 2 hours

## List of Tables and Figures
| Exhibit | Script | Output File |
| :--- | :--- | :--- |
| Figure 1a-1d | `NVP_Code.do` lines 937-1115 | `Figure_1a_Log_Units.pdf` `Figure_1b_Log_Units_Tobacco_Unflavored.pdf` `Figure_1c_Log_Units_Flavored.pdf` `Figure_1d_Log_Units_Mint.pdf` |
| Figure 2a-2d | `NVP_Code.do` line 1156-1495| `Figure_2_placebo_beta_log_units_per_capita.gph` `Figure_2_placebo_beta_log_units_flavored_per_capita.gph` `Figure_2_placebo_beta_log_units_tob_unflav_per_capita.gph` `Figure_2_placebo_beta_log_units_mint_per_capita.gph` |
|Figure 3|`NVP_Code.do` lines 1498-1851| `Figure_3a_Point_Estimates_Sales_log.pdf` `Figure_3b_Stacked_Point_Estimates_Flavors.pdf` |
|Figure 4|`NVP_Code.do` lines 1853-2238 `Cigarette_Code.do` lines 881-979 | `Figure_4a_Point_Estimates_By_Province.pdf` `Figure_4b_Stacked_Point_Estimates_Flavors_By_Province.pdf`|
|Figure 6|`NVP_Code.do` lines 2243-2377 | `Figure_6a_Stacked_Log_Shopping.pdf` `Figure_6b_Stacked_Log_interest.pdf`|
|Table 1|`NVP_Code.do` lines 2380-2450 | `summary_stats_NVPS.html` `summary_stats_google.html`|
|Table 3|`NVP_Code.do` lines 2453-2578| |
|Figures A2|`NVP_Code.do` lines 2582-2603| `Sales_Trends_Units.pdf` `Sales_Trends_Units_Flavored.pdf` `Sales_Trends_Units_Tobacco_Unflavored.pdf` `Sales_Trends_Units_Mint.pdf`|
|Figures 1e & 5a|`Cigarette_Code.do` lines 639-748| `Figure_1e_Stacked_Log_Cigarettes.pdf` `Figure_5a_Stacked_Log_Cigarettes.pdf`|
|Figure 5d|`Cigarette_Code.do` lines 751-775|`Figure_5d_Stacked_Cigarettes.pdf`
|




## Contact
For questions regarding this replication package, contact Brad Davis at badhhh@missouri.edu.
