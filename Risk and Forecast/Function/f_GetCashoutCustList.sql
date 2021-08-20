/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DBBAL-bodb02" isFunction="1" isNested="0"></info>*/
USE [bodb02]
GO
 
ALTER FUNCTION [dbo].[f_GetCashoutCustList]
(
	@site varchar(10), @VendorID INT = 14
)

/*	
	Created: 20170324@Harper
	Description: #73310 - LA/ Invoice - Integrate Cash Out
	DB: DBEXT.bodb02, DBACC.bodb02

	Revisions:		
	- 20210816@Sophia: add DBBAL [Redmine: #154300]
*/
RETURNS TABLE  
AS
RETURN
	(	
	SELECT c.CustId AS CustID, c.currency AS Currency
	FROM dbo.Dep_CustSuper s WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON s.CustId = c.srecommend
		INNER JOIN DBCUST.CustDB.dbo.TradeCust bt WITH(NOLOCK) ON c.CustId = bt.CustId
	WHERE c.RoleId = 1 AND bt.VendorID = @VendorID
		AND (@site = 'ALL' OR (@site <> 'ALL' AND s.site = @site))	
)
GO
