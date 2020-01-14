In this directory I will share some examples of PL/SQL packages/procedures/functions that I have written that demonstrate my proficiency 
in this area. 

*******************************************************************************************************************************************
                                                            PK_CVR_ERP.sql

This package is a small example of the type of PL/SQL that I like to write. As you can see, I am always leaving comments and notes
to try and make the code as legible as possible for anyone who may need to work on it after me. Within this code, you will find 
examples of:
- Exception handling
- Dynamic SQL Generation
- Cursors
- Logging

The purpose of this package is to check for deltas in the data that we sent out to the ERP and received back into our system. If any 
changes were made in the ERP, they would be identified in this process and subsequently loaded into our system by the package. This helped
keep our internal system and the external ERP in balance without the need of manual journals.
*******************************************************************************************************************************************
