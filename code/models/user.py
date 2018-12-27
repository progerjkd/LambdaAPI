from db import engine
from flywheel import Model, Field, STRING, NUMBER


class UserModel(Model):
    name = Field(type=STRING, hash_key=True)
    dateOfBirth = Field(type=NUMBER, coerce=True)

    __metadata__ = {
        '_name': 'Users',
        'throughput': {
            'read': 10,
            'write': 5,
        }
    }

    def __init__(self, name, dateOfBirth):
        self.name = name
        self.dateOfBirth = dateOfBirth

    def json(self):
        return {'name': self.name, 'dateOfBirth': self.dateOfBirth}

    @classmethod
    def find_by_name(cls, name):
        return engine.query(cls).filter(name=name).first()

    def save_to_db(self):
        engine.save(self)


engine.register(UserModel)
engine.create_schema()
