# Restricting Sales of Flavored Nicotine Vaping Products: Effects on Nicotine Vaping Product and Cigarette Sales in Canada
**Authors:** Brad Davis, Abigail Friedman, Michael Pesko
**Status:** Under Review  
**Maintainer:** Brad Davis, Post Doctoral Scholar, University of Missouri  
**Last Updated:** May 2026

## Overview

We examine the effects of province level nicotine vaping product (NVP) flavor restrictions on cigarette sales and NVP sales in gas and convenience stores. Using a stacked DID model, we estimate that flavor restrictions increased cigarette sales by 9.6\%. In gas and convenience stores, these restrictions nearly eliminated flavored non-menthol and menthol NVP sales while increasing tobacco and unflavored NVP sales by 123.4\%. Substitution patterns arise in Canada despite its strict tobacco control environment, suggesting that patterns of substitution between e-cigarettes and cigarettes may be generalizable across countries with different tobacco regulatory strengths.

## Repository Structure
├── data/           # Raw and processed data (not committed — see .gitignore)
├── code/           # Analysis scripts
├── output/         # Tables, figures, and results
├── docs/           # Notes, meeting summaries, documentation
└── README.md

## Requirements

Stata 18.1 or greater

## How to Run
After acquiring data and moving to data folder, run NVP_code.do for cleaning and analysis of NVP sales data. Run Cigarette_code.do for cleaning and analysis of cigarette sales data. 

## Data Sources

NVP Sales - NielsenIQ,
Cigarette Sales - Health Canada,
Google Trends - Google

## Contact

Brad Davis — badhhh@missouri.edu — Social Impact Lab, University of Missouri
