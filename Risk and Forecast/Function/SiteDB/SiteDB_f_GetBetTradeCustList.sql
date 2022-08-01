/*<info serverAlias="DBSID-bodb02" isFunction="1" isNested="0"></info>*/
CREATE FUNCTION [dbo].[SiteDB_f_GetBetTradeCustList]
(
	@site varchar(10)
)

/*	Created: 20220801@Victoria
	Task: get bettrade cust list
	DB: DBSID-bodb02
	Revisions:
		- 20220801@Victoria: Create Function[Redmine: #175297]
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
	FROM CustDB.dbo.Dep_CustSuper s WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON s.CustId = c.srecommend
		INNER JOIN DBCUST.CustDB.dbo.BetTradeCust bt WITH(NOLOCK) ON c.CustId = bt.CustId
	WHERE c.RoleId = 1
		AND (@site = 'ALL' OR (@site <> 'ALL' AND s.site = @site))

	RETURN
END

