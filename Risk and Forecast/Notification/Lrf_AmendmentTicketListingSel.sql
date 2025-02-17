/*<info serverAlias="DBOIC-bodb_OIC" executers="wsv_lap" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_AmendmentTicketListingSel]
	@SessionID 		NVARCHAR(300),
	@AgentList 		VARCHAR(MAX),
	@MoveBetsDay 	SMALLDATETIME,
	@BalanceUpDay 	SMALLDATETIME,
	@EventDate 		DATETIME OUTPUT,
	@MatchId		INT OUTPUT
AS

/*
	Created by: Kai
	Date: 2025-02-10
	Task: OIC - Move Result Amendment to DBOIC.bodb_OIC db054/db055
	DB: DBOIC-bodb_OIC

	Revisions:
		- 20250210@Kai: Move Result Amendment to DBOIC.bodb_OIC db054/db055 - [RedmineId: #217146]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE	@ResultId BIGINT = 0
	DECLARE @tmpAg TABLE (CustId INT)
	DECLARE @DocHandler INT

	SELECT @EventDate = lra.EventDate, @MatchId = lra.MatchID, @ResultId = lra.ResultID 
	FROM LicenseeResultAmendment lra WITH(NOLOCK)
    WHERE lra.SessionID = @SessionID

	IF(@ResultId = 0) 
		RETURN

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

		INSERT INTO @tmpAg(CustId)
		SELECT data.AgentId
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT) AS Data 
		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'
		RETURN
	END CATCH;

	SELECT lrad.TransID AS RefNo
		,SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS ExternalId
		,c.username AS SystemId
	FROM LicenseeResultAmendmentDetails lrad WITH(NOLOCK)
		INNER JOIN @tmpAg ta ON ta.CustId = lrad.Recommend
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = lrad.CustID
	WHERE lrad.ResultID = @ResultId
END