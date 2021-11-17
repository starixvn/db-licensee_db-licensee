/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BA_CurrencySel]		
AS	
/*
	Created: 20110808@Henry
	Task : Get all the currency for BA betlist
	DB: DBEXT.bodb02

	Revisions:
		- 20110808@Henry: Initialize SP
    
	Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	declare @temp as table (currency int)

	insert into @temp
	SELECT 
		distinct Currency 
	FROM bodb_Licensee.dbo.LicenseeCust lc (nolock)
	

	SELECT 
		t.currency, 
		e.currency as currencyname
	FROM 
		@temp t
	INNER JOIN exchange e with (nolock) ON t.currency = e.exchangeid

END
GO