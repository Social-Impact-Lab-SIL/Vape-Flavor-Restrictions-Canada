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
   - `01_clean_data.do`
   - `02_analysis.do`
   - `03_generate_figures.do`
3. **Estimated Run Time:** [e.g., 5 minutes / 2 hours]

## List of Tables and Figures
| Exhibit | Script | Output File |
| :--- | :--- | :--- |
| Figure 1a- 1d | `NVP_Code.do` lines 937-1115 | `Figure_1a_Log_Units.pdf` `Figure_1b_Log_Units_Tobacco_Unflavored.pdf` `Figure_1c_Log_Units_Flavored.pdf` `Figure_1d_Log_Units_Mint.pdf` |
| Figure 2a- 2d | `NVP_Code.do` line 1156- 1495| `Figure_2_placebo_beta_log_units_per_capita.gph``Figure_2_placebo_beta_log_units_flavored_per_capita.gph``Figure_2_placebo_beta_log_units_tob_unflav_per_capita.gph``Figure_2_placebo_beta_log_units_mint_per_capita.gph` |
|Figure 3|`NVP_Code.do` lines 1498- 1851| `Figure_3a_Point_Estimates_Sales_log.pdf``Figure_3b_Stacked_Point_Estimates_Flavors.pdf`
## Contact
For questions regarding this replication package, contact Brad Davis at badhhh@missouri.edu.
