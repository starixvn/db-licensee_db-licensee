/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="1" isNested="0"></info>*/
USE [bodb02]
GO

ALTER FUNCTION [dbo].[Lrf_f_GetCustId]
(
    @LicenseeID INT ,
    @LicenseeType VARCHAR(100) = NULL ,
    @CurrencyName VARCHAR(20) = NULL 
 )
RETURNS TABLE
AS

/*
	Created: 20110304@Anders
	Task : Daily Statement
	DB: DBACC.bodb02
	Original:

	Revisions:	
		- 20130123@Daniel: Change link server alias
		- 20141112@Victor: use f_SelLicenseeCust instead of licenseecust (#Redmine 25864)
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]

	Purpose: Select all custid by licenseeid, currencyname, and licenseetype
*/

RETURN
	( SELECT    CustId
		FROM      custInfo WITH ( NOLOCK )
		WHERE     CustID IN (
				SELECT	CustID FROM bodb_licensee.dbo.f_SelLicenseeCust(@LicenseeID)
				WHERE   LicenseeID = @LicenseeID
						AND CurrencyName = COALESCE(@CurrencyName, CurrencyName)
						AND [Description] = COALESCE(@LicenseeType, [Description]) )
				AND RoleId = 2
	)
GO