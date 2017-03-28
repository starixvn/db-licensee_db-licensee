USE [bodb02]
GO
/****** Object:  UserDefinedFunction [dbo].[f_DepSuper_1]    Script Date: 6/25/2015 2:39:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER FUNCTION [dbo].[f_GetCashoutCustList]
(
	@site varchar(10)
)

/*	Created: 20170324@Harper
	Description: #73310 - LA/ Invoice - Integrate Cash Out
	DB: DB052/bodb02, DB06/bodb02
	Revisions:
		
*/
RETURNS @returntable TABLE 
(
	CustId INT,
	Currency TINYINT
)
AS
BEGIN
	INSERT INTO @returntable(CustId, Currency)
	SELECT c.CustId, c.currency
	FROM dbo.Dep_CustSuper s WITH(NOLOCK)
		INNER JOIN dbo.Customer c WITH(NOLOCK) ON s.CustId = c.srecommend
		INNER JOIN DBCUST.CustDB.dbo.TradeCust bt WITH(NOLOCK) ON c.CustId = bt.CustId
	WHERE c.RoleId = 1
		AND (@site = 'ALL' OR (@site <> 'ALL' AND s.site = @site))

	RETURN
END
