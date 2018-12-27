from flask_restful import Resource, reqparse
from models.user import UserModel
import datetime


class User(Resource):
    parser = reqparse.RequestParser()
    parser.add_argument('dateOfBirth',
                        type=str,
                        required=True,
                        help="This field cannot be left blank!"
                        )

    def get(self, name):
        user = UserModel.find_by_name(name)

        if user:
            birthday_diff = self.check_birthday(user.dateOfBirth)
            if birthday_diff == 0:
                msg = {'message': "Hello, {}! Happy birthday!".format(user.name)}
            else:
                msg = {'message': "Hello, {}! Your birthday is in {} days".format(user.name, birthday_diff)}
        else:
            msg = {'message': "User {} not found!".format(name)}

        return msg, 200 if user else 404

    def put(self, name):
        data = User.parser.parse_args()

        if not self.check_birthday_format(data['dateOfBirth']):
            return {'message': 'Invalid date format.'}, 400

        data['dateOfBirth'] = datetime.datetime.strptime(data['dateOfBirth'], "%Y-%m-%d").strftime('%s')

        user = UserModel.find_by_name(name)

        if user is None:
            user = UserModel(name, data['dateOfBirth'])
        else:
            user.dateOfBirth = data['dateOfBirth']

        user.save_to_db()

        return '', 204

    def check_birthday_format(self, birth_date):
        try:
            datetime.datetime.strptime(birth_date, '%Y-%m-%d')
            return True
        except ValueError:
            return False

    def check_birthday(self, dateOfBirth):
        birth_day = int(datetime.date.today().strftime('%j'))
        today = int(datetime.date.fromtimestamp(dateOfBirth).strftime('%j'))
        year = int(datetime.date.fromtimestamp(dateOfBirth).strftime('%Y'))

        if self.check_leap_year(year):
            today -= 1

        diff = today - birth_day
        if diff < 0:
            diff += 365

        return diff

    def check_leap_year(self, year):
        if (year % 4) == 0:
            if (year % 100) == 0:
                if (year % 400) == 0:
                    leap = True
                else:
                    leap = False
            else:
                leap = True
        else:
            leap = False

        return leap
