ALTER PROCEDURE [dbo].[Acc_MoveBet_ExchangeDailyOandaSel]

@ExchangeDate SMALLDATETIME = NULL

AS

/*  Created: Henry  

	Date: 2012-07-12

    TASk : Get data to insert to exchangedailyoanda in Kahnawake server

    DB: DB054.bodb02

   

    Revisions:  

		20120718@Henry: Change to get data from DB054 (old: DB052)

	Param's Explanation:  

*/

BEGIN

SET NOCOUNT ON

IF (@ExchangeDate IS NULL)
	BEGIN
		SET @ExchangeDate = Convert(datetime, Convert(varchar, GETDATE(),111) )
	END

SELECT

	exchangedate,

	exchangeid,

	code,

	myr,

	usd,

	eur,

	cny,

	actualrate



FROM ExchangeDailyOanda WITH (NOLOCK)

WHERE exchangedate = @ExchangeDate

FOR xml PATH ('exchangedailyoanda'), ROOT ('root')

END


