/*<info serverAlias="DBEXT-bodb02,DBACC-bodb02,DB042-bodb02" selecters="bodbLicenseeNet" viewers="" isFunction="1" isNested="1"></info>*/

CREATE FUNCTION [dbo].[Lrf_f_GetExchangeRate]
(
    @FromDate				SMALLDATETIME,
    @ToDate					SMALLDATETIME,
    @BaseCurrency			VARCHAR(3) = '',
    @DefaultBaseCurrency	VARCHAR(3) = ''			
 )
RETURNS TABLE
AS

/*
	Created: 20190619@Amanda
	Task : Get exchange rate
	DB: DBEXT-bodb02,DBACC-bodb02,DB042-bodb02
	Original:

	Revisions:	
		- 20190619@Amanda: Create function[Redmine #112531]
*/

RETURN
	SELECT	FirstExchangeDateByMonth						AS FromDate,			LastExchangeDateByMonth							AS ToDate, 			ExchangeID,			USD,			EUR,			GBP,			CASE				WHEN @BaseCurrency = 'USD' THEN USD
				WHEN @BaseCurrency = 'EUR' THEN EUR
				WHEN @BaseCurrency = 'GBP' THEN GBP
				WHEN @BaseCurrency = 'MYR' THEN MYR
				WHEN @BaseCurrency = 'CNY' THEN CNY
				WHEN @BaseCurrency = 'THB' THEN THB
				WHEN @BaseCurrency = 'IDR' THEN IDR				WHEN @BaseCurrency = 'INH' THEN INH  				ELSE 1			END												AS Rate,			CASE				WHEN @DefaultBaseCurrency = 'USD' THEN USD
				WHEN @DefaultBaseCurrency = 'EUR' THEN EUR
				WHEN @DefaultBaseCurrency = 'GBP' THEN GBP
				WHEN @DefaultBaseCurrency = 'MYR' THEN MYR
				WHEN @DefaultBaseCurrency = 'CNY' THEN CNY
				WHEN @DefaultBaseCurrency = 'THB' THEN THB
				WHEN @DefaultBaseCurrency = 'IDR' THEN IDR				WHEN @DefaultBaseCurrency = 'INH' THEN INH  				ELSE 1			END												AS DefaultRate	FROM Lrf_f_GetSubExchangeDaily(@FromDate, @ToDate) e
GO