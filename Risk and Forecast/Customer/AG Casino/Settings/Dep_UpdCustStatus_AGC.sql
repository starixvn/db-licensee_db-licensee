CREATE PROCEDURE	dbo.Dep_UpdCustStatus_AGC
	@CustIDs	VARCHAR(MAX),
	@IsEnabled	BIT
AS
/*
	Created: 20140818@Victor
	Task: Update status of AG Casino product for Members
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
	SET IsEnabled = @IsEnabled
	WHERE CustID IN (SELECT CustID FROM #CustList)

	INSERT INTO dbo.Dep_CustSetting_AGC (CustID, AGGroup, IsEnabled)
	SELECT c.CustID, '', @IsEnabled
	FROM #CustList c
	WHERE NOT EXISTS(SELECT 1 FROM dbo.Dep_CustSetting_AGC cs WITH (NOLOCK) WHERE cs.CustID = c.CustID)

	DROP TABLE #CustList
END

GO
