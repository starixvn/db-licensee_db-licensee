
/* Insert Service Task */
IF NOT EXISTS(SELECT 1 FROM Service_ScheduledTask WHERE [Description]= 'Lrf Domain Checker')
BEGIN 
	INSERT INTO Service_ScheduledTask ([Description], CronExpression,Implementation,Configuration, Active)
	VALUES('Lrf Domain Checker', '0 0/1 * 1/1 * ? *','DomainChecker.ScheduledTask.Implement.DomainCheckerJob','',1)
END