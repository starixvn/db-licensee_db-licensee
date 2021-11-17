ALTER PROCEDURE [dbo].[Acc_ExchangeDailyOandaIns]
@Code varchar(5),
@MYR float,
@USD float,
@EUR float,
@CNY float,
@rundate datetime = null,
@ErrCode int = 0 OUTPUT,
@ErrMsg nvarchar(200) = '' OUTPUT
AS
/*
Created: Henry
Task : Insert the rate daily
DB: 
Revisions:
	
*/		
SET NOCOUNT ON
DECLARE @exchange TABLE(id int identity(1,1), exchangeid int,MultipliedBy int)
DECLARE @date datetime

IF @rundate is null
	set @date = convert(datetime,convert(nvarchar(20), getdate(), 101))
ELSE
	set @date = convert(datetime,convert(nvarchar(20), @rundate, 101))


IF @Code = 'UUS'
BEGIN
	IF NOT EXISTS (SELECT 1 FROM ExchangeDailyOanda (nolock) WHERE ExchangeDate=@date AND ExchangeId = 20  )
	BEGIN
		INSERT INTO ExchangeDailyOanda (ExchangeId,ExchangeDate,Code,MYR,USD,EUR,CNY)
		VALUES (20,@date,'UUS',2E-101,2E-101,2E-101,2E-101)
	END
	ELSE
	BEGIN
		UPDATE ExchangeDailyOanda with (rowlock,updlock)
			SET 
				MYR = 2E-101,
				USD = 2E-101,
				EUR = 2E-101,
				CNY = 2E-101
			WHERE ExchangeId = 20 AND ExchangeDate=@date 
	END
	
	RETURN
END

INSERT INTO @exchange(exchangeid, MultipliedBy)
SELECT 
	exchangeid, MultipliedBy 
FROM exchange (nolock)
WHERE Code = @Code

IF @@ROWCOUNT > 0
BEGIN
	DECLARE @i int, @max int, @ExchangeId int, @MultipliedBy int
	SET @i = 1
	SELECT @max = count(1) from @exchange
	
	WHILE (@i<=@max)
	BEGIN
		SELECT 
			@ExchangeId = exchangeid , 
			@MultipliedBy = MultipliedBy 
		FROM @exchange
		WHERE id = @i
		
		--Check exist, if false then insert 
		IF NOT EXISTS (SELECT 1 FROM ExchangeDailyOanda (nolock) WHERE ExchangeId = @ExchangeId AND ExchangeDate=@date AND Code=@Code )
		BEGIN
			INSERT INTO ExchangeDailyOanda (ExchangeId,ExchangeDate,Code,MYR,USD,EUR,CNY)
			VALUES (@ExchangeId,@date,@Code,@MYR * @MultipliedBy,@USD * @MultipliedBy,@EUR * @MultipliedBy,@CNY * @MultipliedBy)
		END
		ELSE
		BEGIN
			UPDATE ExchangeDailyOanda with (rowlock,updlock)
			SET 
				MYR = @MYR * @MultipliedBy,
				USD = @USD * @MultipliedBy,
				EUR = @EUR * @MultipliedBy,
				CNY = @CNY * @MultipliedBy
			WHERE ExchangeId = @ExchangeId AND ExchangeDate=@date AND Code=@Code
		END
		
		if @@Error <> 0
		BEGIN
			Select @ErrMsg = 'Exchange rate insert fail.'
				 ,@ErrCode = 100
			return
		END
		
		SET @i = @i + 1
	END
	
END



GO
GRANT EXECUTE ON [dbo].[Acc_ExchangeDailyOandaIns] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_ExchangeDailyOandaIns] TO [vnteam] AS [dbo] 