CREATE PROCEDURE	dbo.Dep_UpdCustSetting_AGC
	@CustIDs	VARCHAR(MAX),
	@AGGroup	VARCHAR(20)
AS
/*
	Created: 20140818@Victor
	Task: Update setting of AG Casino product for Members
	DB: DBTXN.CustDB
	Original:
	Revisions:
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #CustList (CustID INT)

	INSERT INTO #CustList (CustID)
	SELECT val FROM dbo.strSplit(@CustIDs,',')

	UPDATE dbo.Dep_CustSetting_AGC WITH (ROWLOCK, UPDLOCK)
	SET AGGroup = @AGGroup
	WHERE CustID IN (SELECT CustID FROM #CustList)

	INSERT INTO dbo.Dep_CustSetting_AGC (CustID, AGGroup, IsEnabled)
	SELECT c.CustID, @AGGroup, 0
	FROM #CustList c
	WHERE NOT EXISTS(SELECT 1 FROM dbo.Dep_CustSetting_AGC cs WITH (NOLOCK) WHERE cs.CustID = c.CustID)

	DROP TABLE #CustList

END

GO
