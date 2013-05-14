ALTER FUNCTION [dbo].[Lrf_f_GetCustId]
    (
      @LicenseeID INT ,
      @LicenseeType VARCHAR(100) = NULL ,
      @CurrencyName VARCHAR(20) = NULL 
    )
RETURNS TABLE
AS

 /*
Created: 
Task : Daily Statement
DB: DBRPT/BODB02
Original: 
Revisions:	
    - 20130123@Daniel: Change link server alias


20110304@Anders	: Create

Purpose: Select all custid by licenseeid, currencyname, and licenseetype

*/

RETURN
    ( SELECT    CustId
      FROM      custInfo WITH ( NOLOCK )
      WHERE     CustID IN (
                SELECT  CustID
                FROM    DBLIC.bodb_Licensee.dbo.LicenseeCust WITH ( NOLOCK )
                WHERE   LicenseeID = @LicenseeID
                        AND CurrencyName = COALESCE(@CurrencyName,
                                                    CurrencyName)
                        AND [Description] = COALESCE(@LicenseeType,
                                                     [Description]) )
                AND RoleId = 2
    )



GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_f_GetCustId] TO [vnteam] AS [dbo]