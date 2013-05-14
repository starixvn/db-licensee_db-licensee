set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go

ALTER  PROCEDURE [dbo].[Lrf_GetExchangeRate]
	@Date SMALLDATETIME = NULL	,
	@Currency	INT,
	@Amount FLOAT,
	@AmountToEUR FLOAT OUTPUT ,
	@AmountToUSD FLOAT OUTPUT 
AS
/*    
 Created : Henry    
 Date : 2012-05-11  
    Task : convert a currency to base currency EURO
    DB  : DB052.bodb02    
     
    Revisions: 
		- 20130403@Jim:support base currency USD      
*/  

BEGIN  
SET NOCOUNT ON   

IF ISNULL(@Date,'')='' --If no input then will get today
	SET @Date = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)
ELSE
	SET @Date = CONVERT(VARCHAR(10), @Date, 120)

DECLARE @maxExchangeDate DATETIME, @currentDate DATETIME, @lastEndOfMonth DATETIME


--Get today 
SET @currentDate = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

--Get lastest exchangedate
SELECT @maxExchangeDate=MAX(exchangedate) FROM ExchangeDailyOanda (NOLOCK)	

--If current month then get lastest rate
IF (@Date>=@currentDate OR (@Date<@currentDate AND year(@Date)=year(@currentDate) AND month(@Date)=month(@currentDate)))
BEGIN
	SELECT @AmountToEUR = EUR * @Amount ,
			@AmountToUSD = USD * @Amount 
	FROM ExchangeDailyOanda (NOLOCK)	
	WHERE ExchangeDate = @maxExchangeDate AND ExchangeId = @Currency
END
ELSE --Get the end of last month rate
BEGIN
	SELECT @lastEndOfMonth = CONVERT(VARCHAR(10),  DATEADD(DAY,-1,DATEADD(MONTH,1,DATEADD(day,(0-(DATEPART(dd,@Date)-1)),@Date))),120)
	SELECT @AmountToEUR = EUR * @Amount ,
		  @AmountToUSD = USD * @Amount 	
	FROM ExchangeDailyOanda (NOLOCK)	
	WHERE ExchangeDate = @lastEndOfMonth AND ExchangeId = @Currency
END
	

	
END  

GO
GRANT EXECUTE ON [dbo].[Lrf_GetExchangeRate] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_GetExchangeRate] TO [vnteam]    

