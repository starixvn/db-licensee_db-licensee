/*<info serverAlias="DBEXT-bodb02,DBBAL-bodb02" executers="bodbAdminNet,bodbLicenseeNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Lrf_SelBalanceUpDay]
AS

/*
	Created: 20101210@Henry
	Task : Get move bet day, balanceup day
	DB: DBEXT-bodb02
	Original: [Age_SelBalanceUpDay]

	Revisions:
		- 20120504@Henry: temporary remove custid = 3
		- 20210518@Percy: Change way to get MoveBetsDay [RedmineID: #154866]
		- 20210816@Sophia: add DBBAL [Redmine: #154300]
		- 20211111@Sol: Split Transfer out of bettrans/Support IPv6 - [RedmineID: #164301]

	Param's Explanation:
*/

SET NOCOUNT ON
BEGIN
	DECLARE @BalanceUpDay SMALLDATETIME, @MoveBetsDay SMALLDATETIME

	---using this when release to PROD---
	SELECT TOP 1 @BalanceUpDay = winlostdate
	FROM dbo.Transfer t WITH(NOLOCK)
	WHERE bettype = 20000 AND custid = 3

	EXEC dbo.NAP_Admin_GetMovebetDate @MovebetDate = @MoveBetsDay OUTPUT

	SELECT @BalanceUpDay AS BalanceUpDay, @MoveBetsDay AS MoveBetsDay
END
GO