/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_AmendmentTicketListingSel]
	@SessionID NVARCHAR(300),
	@AgentList VARCHAR(MAX),
	@MoveBetsDay SMALLDATETIME,
	@BalanceUpDay SMALLDATETIME,
	@EventDate DATETIME OUTPUT,
	@MatchCode NVARCHAR(50) = '' OUTPUT,
	@HomeId INT = 0 OUTPUT,
	@AwayId INT = 0 OUTPUT,
	@IsNeutral BIT = 0 OUTPUT,
	@SportType TINYINT = 0 OUTPUT,
	@ProductId TINYINT = 0 OUTPUT
AS

/*
	Created by: [20211227@Howard]
	Task: Get Amendment Ticket Listing
	DB: DBEXT.bodb02

	Revisions:
		- 20211227@Howard: Initial SP [Redmine: #164893]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE	@MatchId INT
	DECLARE	@ResultId BIGINT = 0
	DECLARE @tmpAg TABLE (CustId INT)
 	DECLARE @DocHandler INT

	SELECT @EventDate = lra.EventDate, @MatchId = lra.MatchID, @ResultId = lra.ResultID 
	FROM bodb_licensee.dbo.LicenseeResultAmendment lra WITH(NOLOCK)
    WHERE lra.SessionID = @SessionID

	IF(@ResultId = 0) 
		RETURN

    -- Match Info
	IF(@EventDate > @MoveBetsDay) 
	BEGIN
		SELECT @MatchCode = m.matchcode, @IsNeutral = m.IsNeutral, @SportType = m.sporttype, @HomeId = m.homeid, @AwayId = m.awayid 
		FROM dbo.match m WITH(NOLOCK) WHERE m.matchid = @MatchId 
	END
	ELSE IF(@EventDate >= @BalanceUpDay)
	BEGIN
		SELECT @MatchCode = m.matchcode, @IsNeutral = m.IsNeutral, @SportType = m.sporttype, @HomeId = m.homeid, @AwayId = m.awayid 
		FROM dbo.match14 m WITH(NOLOCK) WHERE m.matchid = @MatchId
		END
	ELSE 
	BEGIN
		SELECT @MatchCode = m.matchcode, @IsNeutral = m.IsNeutral, @SportType = m.sporttype, @HomeId = m.homeid, @AwayId = m.awayid 
		FROM DBARC.bodb_Archive.dbo.match_bk m WITH(NOLOCK) WHERE m.matchid = @MatchId
	END

	SELECT TOP 1 @ProductId = sbm.ProductID
	FROM dbo.SportBettypeMatrix sbm WITH(NOLOCK)
	WHERE sbm.SportType = @SportType AND sbm.ProductID IN (1,3)
	-- End Match Info

	--Ticket Listing
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
		,SUBSTRING(c.username2, CHARINDEX('$',c.username2)+1, LEN(c.username2)-CHARINDEX('$',c.username2)) AS ExternalId
		,c.username AS SystemId
	FROM bodb_licensee.dbo.LicenseeResultAmendmentDetails lrad WITH(NOLOCK)
		INNER JOIN @tmpAg ta ON ta.CustId = lrad.Recommend
		INNER JOIN dbo.Customer c WITH(NOLOCK)
			ON c.custid = lrad.CustID
	WHERE lrad.ResultID = @ResultId
	-- End Ticket Listing
END