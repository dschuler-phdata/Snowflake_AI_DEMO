-- ========================================================================
-- STEP 1: Create Snowflake Objects
-- ========================================================================
USE ROLE accountadmin;

-- Enable Snowflake Intelligence by creating the Config DB & Schema
CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;

-- Allow anyone to see the agents in this schema
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;


create or replace role SF_Intelligence_Demo;
SET current_user_name = CURRENT_USER();

-- Step 2: Use the variable to grant the role
GRANT ROLE SF_Intelligence_Demo TO USER IDENTIFIER($current_user_name);
GRANT CREATE DATABASE ON ACCOUNT TO ROLE SF_Intelligence_Demo;

-- Create a dedicated warehouse for the demo with auto-suspend/resume
CREATE OR REPLACE WAREHOUSE Snow_Intelligence_demo_wh 
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;


-- Grant usage on warehouse to admin role
GRANT USAGE ON WAREHOUSE SNOW_INTELLIGENCE_DEMO_WH TO ROLE SF_Intelligence_Demo;

-- Alter current user's default role and warehouse to the ones used here
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_ROLE = SF_Intelligence_Demo;
ALTER USER IDENTIFIER($current_user_name) SET DEFAULT_WAREHOUSE = Snow_Intelligence_demo_wh;


-- Switch to SF_Intelligence_Demo role to create demo objects
use role SF_Intelligence_Demo;

-- Create database and schema
CREATE OR REPLACE DATABASE SF_AI_DEMO;
USE DATABASE SF_AI_DEMO;

CREATE SCHEMA IF NOT EXISTS DEMO_SCHEMA;
USE SCHEMA DEMO_SCHEMA;

-- Create file format for CSV files
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    ESCAPE = 'NONE'
    ESCAPE_UNENCLOSED_FIELD = '\134'
    DATE_FORMAT = 'YYYY-MM-DD'
    TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
    NULL_IF = ('NULL', 'null', '', 'N/A', 'n/a');

    
-- ========================================================================
-- STEP 2: Create Git API integration and clone repo
-- ========================================================================
use role accountadmin;
-- Create API Integration for GitHub (public repository access)
CREATE OR REPLACE API INTEGRATION git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/dschuler-phdata')
    ENABLED = TRUE;


GRANT USAGE ON INTEGRATION GIT_API_INTEGRATION TO ROLE SF_Intelligence_Demo;


use role SF_Intelligence_Demo;
-- Create Git repository integration for the public demo repository
CREATE OR REPLACE GIT REPOSITORY SF_AI_DEMO_REPO
    API_INTEGRATION = git_api_integration
    ORIGIN = 'https://github.com/dschuler-phdata/Snowflake_AI_DEMO.git';

-- Create internal stage for copied data files
CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
    FILE_FORMAT = CSV_FORMAT
    COMMENT = 'Internal stage for copied demo data files'
    DIRECTORY = ( ENABLE = TRUE)
    ENCRYPTION = (   TYPE = 'SNOWFLAKE_SSE');

ALTER GIT REPOSITORY SF_AI_DEMO_REPO FETCH;

-- ========================================================================
-- STEP 3: Load data into internal stage
-- ========================================================================
-- Copy all CSV files from Git repository demo_data folder to internal stage
COPY FILES
INTO @INTERNAL_DATA_STAGE/demo_data/
FROM @SF_AI_DEMO_REPO/branches/main/demo_data/;


COPY FILES
INTO @INTERNAL_DATA_STAGE/unstructured_docs/
FROM @SF_AI_DEMO_REPO/branches/main/unstructured_docs/;

-- Verify files were copied
LS @INTERNAL_DATA_STAGE;
ALTER STAGE INTERNAL_DATA_STAGE refresh;


-- ========================================================================
-- STEP 4: Configure Snowflake Intelligence
-- ========================================================================
-- Switch to accountadmin for integration creation
USE ROLE accountadmin;

-- Grant necessary privileges on database and schema
GRANT ALL PRIVILEGES ON DATABASE SF_AI_DEMO TO ROLE ACCOUNTADMIN;
GRANT ALL PRIVILEGES ON SCHEMA SF_AI_DEMO.DEMO_SCHEMA TO ROLE ACCOUNTADMIN;
-- GRANT USAGE ON NETWORK RULE snowflake_intelligence_webaccessrule TO ROLE accountadmin;

USE SCHEMA SF_AI_DEMO.DEMO_SCHEMA;

-- Create external access integration for web scraping
-- CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION Snowflake_intelligence_ExternalAccess_Integration
-- ALLOWED_NETWORK_RULES = (Snowflake_intelligence_WebAccessRule)
-- ENABLED = true;

-- Create email notification integration
-- CREATE NOTIFICATION INTEGRATION ai_email_int
--   TYPE=EMAIL
--   ENABLED=TRUE;

GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE SF_Intelligence_Demo;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;
GRANT CREATE AGENT ON SCHEMA snowflake_intelligence.agents TO ROLE SF_Intelligence_Demo;

-- GRANT USAGE ON INTEGRATION Snowflake_intelligence_ExternalAccess_Integration TO ROLE SF_Intelligence_Demo;
-- GRANT USAGE ON INTEGRATION AI_EMAIL_INT TO ROLE SF_INTELLIGENCE_DEMO;