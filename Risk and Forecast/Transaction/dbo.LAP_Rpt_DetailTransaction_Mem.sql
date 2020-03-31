/*<info serverAlias="DBBAH-bodb02" executers="bodbLicenseeNet,bodbDownlineNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[LAP_Rpt_DetailTransaction_Mem] 
    @CustID			INT,  
    @FromDate		DATE,  
    @ToDate			DATE,
    @PageSize		INT = NULL,  
    @PageIndex		INT = 1,  
    @TotalRow		INT = 0 OUTPUT 
AS
/*
	Created:Bobby@20200313  
	Task : 130293 - LAP - Detail Transaction Member
	DB: DBBAH/bodb02
	Revisions:  
		- 20200313@Bobby: Initialize [RedmineID: #130293] 
		- 20200330@Louis: Support Statement & Detail Transaction Report in Chinese [RedmineID: #131262]
	
	Param's Explanation:     
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE 
		@currentDate		SMALLDATETIME
		, @currency			INT  
		, @_fromDateTime	SMALLDATETIME
		, @_toDateTime		SMALLDATETIME
		, @_custID			INT

	CREATE TABLE #transactionRpt
    (  
		transid				BIGINT
		, bettype			INT
		, transtime			DATETIME
        , transremark		VARCHAR(200)
        , changedAmt		DECIMAL(15,2) DEFAULT(0)
        , totalAmt			DECIMAL(15,2) DEFAULT(0)
		--, CONSTRAINT PK_Trans PRIMARY KEY (transtime, transid)
		, rowIdx INT PRIMARY KEY
    )

	SELECT @_fromDateTime	= @FromDate
	, @_toDateTime			= @ToDate
	, @_toDateTime			= DATEADD(DAY, 1, @_toDateTime)
	, @_custID				= @custID

	INSERT INTO #transactionRpt (
		transid
		, bettype
		, transtime
		, transremark
		, changedAmt
		, totalAmt
		, rowIdx
	)
	SELECT br.transid
		, br.bettype
		, br.transtime
		, br.transremark
		, br.changedAmt
		, br.totalAmt
		, rowIdx = ROW_NUMBER() OVER(ORDER BY transtime ASC, transid ASC)
	FROM (
		SELECT transid
			, bettype
			, actiondate AS transtime
			, REPLACE([action],'TransLog','Ticket') AS transremark
			, BalanceChanged AS changedAmt
			, NewBalance AS totalAmt
		FROM BalanceRecord.dbo.BalanceRecord_bk br WITH(NOLOCK)
		WHERE custid = @_custid
			AND actiondate BETWEEN @_fromDateTime AND @_toDateTime
			AND BalanceChanged <> 0
	
		UNION ALL
		SELECT transid
			, bettype
			, actiondate AS transtime
			, REPLACE([action],'TransLog','Ticket') AS transremark
			, BalanceChanged AS changedAmt
			, NewBalance AS totalAmt
		FROM bodb02.dbo.BalanceRecord WITH(NOLOCK)
		WHERE custid = @_custid
			AND actiondate BETWEEN @_fromDateTime AND @_toDateTime
			AND BalanceChanged <> 0
	) AS br

	-- SET @TotalRow
	SELECT @TotalRow		= @@ROWCOUNT
	
	DECLARE @_rowStart		INT
		, @_rowEnd			INT
		, @_maxIntValue		INT

	SELECT @_maxIntValue	= POWER(2.,31)-2
		, @PageSize		= CASE WHEN @PageSize > 0 THEN @PageSize ELSE @_maxIntValue END

    SELECT  @PageIndex		= CASE WHEN @PageIndex > 0 THEN @PageIndex - 1 ELSE 0 END,
            @_rowStart		= @PageSize * @PageIndex + 1,
            @_rowEnd		= @_rowStart + @PageSize - 1
	
	SELECT 
		br.transid
		, br.bettype
		, br.transtime
		, br.transremark
		, br.changedAmt
		, br.totalAmt
	FROM #transactionRpt br
	WHERE 
		br.rowIdx BETWEEN @_rowStart AND @_rowEnd
	ORDER BY 
		br.rowIdx

	DROP TABLE #transactionRpt
END
GO