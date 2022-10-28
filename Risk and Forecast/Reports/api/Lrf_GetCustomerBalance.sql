/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_GetCustomerBalance]
	@AgentList		VARCHAR(MAX),
	@ReportDate		SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)		= ''
AS

/*
	Created: 20170120@Joseph
	Task: Dashboard API - Get Current Customer Balance
	DB: DBACC/bodb02
	Original: Lrf_Rpt_CustomerBalance

	Revisions:
		- 20170120@Joseph: Copy from Lrf_Rpt_PlatformWinloss [RedmineID: #70616]
		- 20170613@Paul: return value in THB, IDR rates [RedmineID: #75030]
		- 20170808@Walter: Support UUS currency [RedmineID: #80855]
		- 20170814@Alex: Restrict permission by currency [RedmineID: #80855]
		- 20181031@Percy: Remove linked-server DBLIC [RedmineID: #103660]
		- 20181120@Kathy: Tunning SP - got timeout error [RedmineId:#104824]
		- 20190620@Amanda: Add Base currency param [RedmineID: #112531]
		- 20191115@Merlin: Get data by AgentList instead of LicenseeID and CurrentcyList [RedmineID: #123651]
		- 20210804@Kos: Enhance performance [RedmineId: #159711]
		- 20220914@Evan: Expand length of @BaseCurrency [Redmine #177481]
*/

BEGIN
	SET NOCOUNT ON

	-- Get agent list
	CREATE TABLE #TempAg (
		CustId		INT,
		Currency	INT
	)

	CREATE CLUSTERED INDEX CIX_TempAg ON #TempAg (CustId);

	DECLARE @DocHandler INT
	
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg(CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY

	BEGIN CATCH
		SELECT ErrCode = 100
			,ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH;

	-- Get exchange rate
	DECLARE @Exchange TABLE (
		ExchangeId	INT,
		Rate		FLOAT
	)

	INSERT INTO @Exchange(ExchangeId, Rate)
	SELECT ExchangeID, Rate
	FROM dbo.Lrf_f_GetExchangeRate(@ReportDate, @ReportDate, @BaseCurrency, '') e
	WHERE EXISTS (SELECT 1 FROM #TempAg AS c WHERE c.Currency = e.ExchangeID)

	DECLARE @Date SMALLDATETIME

	SET @Date = @ReportDate

	-- Get balance
	SELECT SUM(b.ClosingBalance * e.Rate) AS ClosingBalance
	FROM bodb_Report.dbo.rptDepWinlost AS b WITH (NOLOCK)
		INNER JOIN #TempAg AS a ON b.recommend = a.CustId
		INNER JOIN @Exchange AS e ON a.Currency = e.ExchangeID
	WHERE b.winlostdate = @Date

	DROP TABLE #TempAg
END
GO